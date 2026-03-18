#!/bin/bash
set -euo pipefail

ROOT="$HOME/qai-borsa-platform"
ENVFILE="$ROOT/.env"
PY="$ROOT/backend-python"
NODE="$ROOT/backend-node"
MIG="$ROOT/db/migrations/001_init.sql"

HFREPO="$ROOT/models/local-bert-repo"
HF_SNAPSHOT_ID="86b5e0934494bd15c9632b12f734a8a67f723594"
BLOB_HASH_CONFIG="45a2321a7ecfdaaf60a6c1fd7f5463994cc8907d"
BLOB_HASH_MODEL="68d45e234eb4a928074dfd868cead0219ab85354cc53d20e772753c6bb9169d3"
BLOB_HASH_TOKENIZER_CFG="e5c73d8a50df1f56fb5b0b8002d7cf4010afdccb"
BLOB_HASH_TOKENIZER_JSON="949a6f013d67eb8a5b4b5b46026217b888021b88"
BLOB_HASH_VOCAB="fb140275c155a9c7c5a3b3e0e77a9e839594a938"

mkdir -p "$ROOT" "$PY/app" "$NODE" "$(dirname "$MIG")"

echo "==> PATH ve servisler"
export PATH="/opt/homebrew/opt/postgresql@16/bin:/opt/homebrew/opt/libpq/bin:$PATH"
brew services start postgresql@16 >/dev/null 2>&1 || true
brew services start redis          >/dev/null 2>&1 || true

command -v jq >/dev/null 2>&1 || brew install jq >/dev/null 2>&1 || true

echo "==> .env dosyası yazılıyor: $ENVFILE"
cat > "$ENVFILE" << "ENV"
DB_HOST=localhost
DB_PORT=5432
DB_NAME=qai
DB_USER=qaiuser
DB_PASSWORD=qaipass
REDIS_HOST=localhost
REDIS_PORT=6379

NODE_API_PORT=8080
PY_API_PORT=8000

JWT_SECRET=ChangeThisInProd_0123456789ABCDEF

WEB3_PROVIDER_URI=https://mainnet.infura.io/v3/a1308e9977764245b8d7b532a59ac7ee
ENV

echo "==> PostgreSQL hazır bekleniyor..."
PGREADY=$(command -v pg_isready || echo /opt/homebrew/opt/postgresql@16/bin/pg_isready)
until "$PGREADY" -h 127.0.0.1 -p 5432 >/dev/null 2>&1; do sleep 1; done
PSQL=$(command -v psql || echo /opt/homebrew/opt/postgresql@16/bin/psql)

echo "==> DB ve kullanıcı oluşturuluyor..."
"$PSQL" -h 127.0.0.1 -p 5432 -U "$(whoami)" -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='qaiuser';" | grep -q 1 || \
  "$PSQL" -h 127.0.0.1 -p 5432 -U "$(whoami)" -d postgres -c "CREATE ROLE qaiuser LOGIN PASSWORD 'qaipass';"
"$PSQL" -h 127.0.0.1 -p 5432 -U "$(whoami)" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='qai';" | grep -q 1 || \
  "$PSQL" -h 127.0.0.1 -p 5432 -U "$(whoami)" -d postgres -c "CREATE DATABASE qai OWNER qaiuser;"

cat > "$MIG" << "SQL"
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounts (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  asset TEXT NOT NULL,
  balance NUMERIC(32,8) NOT NULL DEFAULT 0,
  CONSTRAINT uc_user_asset UNIQUE(user_id, asset)
);

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  market TEXT NOT NULL,
  side TEXT NOT NULL CHECK (side IN (''BUY'',''SELL'')),
  price NUMERIC(32,8) NOT NULL,
  qty   NUMERIC(32,8) NOT NULL,
  status TEXT NOT NULL DEFAULT ''OPEN'',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trades (
  id BIGSERIAL PRIMARY KEY,
  buy_order_id  BIGINT REFERENCES orders(id),
  sell_order_id BIGINT REFERENCES orders(id),
  market TEXT NOT NULL,
  price  NUMERIC(32,8) NOT NULL,
  qty    NUMERIC(32,8) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
SQL
"$PSQL" -h 127.0.0.1 -p 5432 -U qaiuser -d qai -f "$MIG" >/dev/null

echo "==> FastAPI başlatılıyor..."
[ -f "$PY/activate.sh" ] || echo "python3 -m venv .venv312 && source .venv312/bin/activate && pip -q install --upgrade pip uvicorn fastapi python-dotenv" > "$PY/activate.sh"
cat > "$PY/app/main.py" << "PY"
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv(), override=False)

app = FastAPI(title="QAI Python/AI", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

@app.get("/api/ai/ping")
def ping():
    return {"ok": True, "engine": "fastapi", "node_api": os.getenv("NODE_API_PORT")}
PY
[ -f "$PY/app/__init__.py" ] || touch "$PY/app/__init__.py"
cd "$PY"
bash -lc "source ./activate.sh >/dev/null 2>&1 || true; source .venv312/bin/activate"
PY_PORT=$(grep -E "^PY_API_PORT=" "$ENVFILE" | cut -d= -f2); PY_PORT=${PY_PORT:-8000}
lsof -tiTCP:$PY_PORT -sTCP:LISTEN >/dev/null 2>&1 && PY_PORT=$((PY_PORT+1))
/usr/bin/sed -i "" "s/^PY_API_PORT=.*/PY_API_PORT=${PY_PORT}/" "$ENVFILE" || true
pkill -f "uvicorn .*:app" >/dev/null 2>&1 || true
nohup uvicorn app.main:app --host 0.0.0.0 --port "$PY_PORT" --reload >/tmp/qai_fastapi.log 2>&1 & disown
echo "   -> http://127.0.0.1:${PY_PORT}/api/ai/ping"

echo "==> Node backend başlatılıyor..."
mkdir -p "$NODE/src"
if [ ! -f "$NODE/src/index.js" ]; then
  cat > "$NODE/package.json" << "PKG"
{
  "name": "qai-backend-node",
  "private": true,
  "type": "module",
  "version": "0.0.1",
  "scripts": { "start": "node src/index.js" },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3"
  }
}
PKG
  cat > "$NODE/src/index.js" << "JS"
import "dotenv/config";
import express from "express";
import cors from "cors";
import jwt from "jsonwebtoken";
import pkg from "pg";

const app = express();
app.use(cors()); app.use(express.json());
const { Pool } = pkg;
const {
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD,
  NODE_API_PORT=8080, JWT_SECRET="devsecret"
} = process.env;
const pool = new Pool({ host: DB_HOST, port: DB_PORT, database: DB_NAME, user: DB_USER, password: DB_PASSWORD });

app.get("/api/health", async (_req,res)=>{
  try {
    const { rows } = await pool.query("SELECT NOW() now");
    res.json({ ok:true, service:"node", db_time: rows[0].now });
  } catch (e) {
    res.status(500).json({ ok:false, error: e.message });
  }
});

app.post("/api/auth/register", async (req,res)=>{
  const { email, password } = req.body ?? {};
  if(!email || !password) return res.status(400).json({error:"email/password"});
  const hash = password; // demo: bcrypt yoksa düz; prod için bcrypt kullanın
  await pool.query("INSERT INTO users(email,password_hash) VALUES($1,$2) ON CONFLICT (email) DO NOTHING",[email,hash]);
  res.json({ok:true});
});

app.post("/api/auth/login", async (req,res)=>{
  const { email, password } = req.body ?? {};
  const { rows } = await pool.query("SELECT * FROM users WHERE email=$1",[email]);
  if(!rows[0] || rows[0].password_hash !== password) return res.status(401).json({error:"invalid"});
  const token = jwt.sign({ uid: rows[0].id, email }, JWT_SECRET, { expiresIn: "7d" });
  res.json({ token });
});

app.listen(Number(NODE_API_PORT), ()=> console.log("Node API on", NODE_API_PORT));
JS
fi
cd "$NODE"
npm -s install
NODE_PORT=$(grep -E "^NODE_API_PORT=" "$ENVFILE" | cut -d= -f2); NODE_PORT=${NODE_PORT:-8080}
lsof -tiTCP:$NODE_PORT -sTCP:LISTEN >/dev/null 2>&1 && NODE_PORT=$((NODE_PORT+1))
/usr/bin/sed -i "" "s/^NODE_API_PORT=.*/NODE_API_PORT=${NODE_PORT}/" "$ENVFILE" || true
export NODE_API_PORT=$NODE_PORT
pkill -f "node .*src/index.js" >/dev/null 2>&1 || true
nohup npm run start >/tmp/qai_node.log 2>&1 & disown
echo "   -> http://127.0.0.1:${NODE_PORT}/api/health"

echo "==> Sağlık kontrolü"
sleep 2
curl -s "http://127.0.0.1:${NODE_PORT}/api/health" || true; echo
curl -s "http://127.0.0.1:${PY_PORT}/api/ai/ping" || true; echo

echo "==> Örnek register/login"
curl -s -X POST "http://127.0.0.1:${NODE_PORT}/api/auth/register" \
  -H "Content-Type: application/json" -d "{\"email\":\"erenuludemir@hotmail.com\",\"password\":\"secret\"}" >/dev/null || true
TOKEN=$(curl -s -X POST "http://127.0.0.1:${NODE_PORT}/api/auth/login" \
  -H "Content-Type: application/json" -d "{\"email\":\"erenuludemir@hotmail.com\",\"password\":\"secret\"}" | jq -r .token 2>/dev/null || echo "")
echo "TOKEN: ${TOKEN:-<null>}"

echo
echo "ℹ️  Node API:   http://localhost:${NODE_PORT}/api/health"
echo "ℹ️  Python AI:  http://localhost:${PY_PORT}/api/ai/ping"
echo "📄 Loglar: /tmp/qai_node.log  /tmp/qai_fastapi.log"

echo "==> HF benzeri model repo yapısı kuruluyor: $HFREPO"
mkdir -p "$HFREPO/blobs" "$HFREPO/refs" "$HFREPO/snapshots/$HF_SNAPSHOT_ID"

write_or_copy () {
  local target="$1"; local src_var="$2"; local label="$3"
  local src="${!src_var:-}"
  if [ -n "${src:-}" ] && [ -f "$src" ]; then
    cp -f "$src" "$target"
    echo "   -> $label kopyalandı: $target"
  else
    cat > "$target" << "CFG"
__PLACEHOLDER__
CFG
    echo "   -> $label YAZILDI/PLACEHOLDER: $target"
  fi
}

cat > "$HFREPO/blobs/$BLOB_HASH_CONFIG" << "JSON"
{
  "architectures": ["BertForMaskedLM"],
  "attention_probs_dropout_prob": 0.1,
  "gradient_checkpointing": false,
  "hidden_act": "gelu",
  "hidden_dropout_prob": 0.1,
  "hidden_size": 768,
  "initializer_range": 0.02,
  "intermediate_size": 3072,
  "layer_norm_eps": 1e-12,
  "max_position_embeddings": 512,
  "model_type": "bert",
  "num_attention_heads": 12,
  "num_hidden_layers": 12,
  "pad_token_id": 0,
  "position_embedding_type": "absolute",
  "transformers_version": "4.6.0.dev0",
  "type_vocab_size": 2,
  "use_cache": true,
  "vocab_size": 30522
}
JSON
echo "   -> config.json YAZILDI: $HFREPO/blobs/$BLOB_HASH_CONFIG"

cat > "$HFREPO/blobs/$BLOB_HASH_TOKENIZER_CFG" << "JSON"
{"do_lower_case": true, "model_max_length": 512}
JSON
echo "   -> tokenizer_config.json YAZILDI: $HFREPO/blobs/$BLOB_HASH_TOKENIZER_CFG"

if [ -n "${HF_SRC_TOKENIZER_JSON:-}" ] && [ -f "$HF_SRC_TOKENIZER_JSON" ]; then
  cp -f "$HF_SRC_TOKENIZER_JSON" "$HFREPO/blobs/$BLOB_HASH_TOKENIZER_JSON"
  echo "   -> tokenizer.json KOPYALANDI: $HFREPO/blobs/$BLOB_HASH_TOKENIZER_JSON"
else
  cat > "$HFREPO/blobs/$BLOB_HASH_TOKENIZER_JSON" << "JSON"
{"version":"1.0","truncation":null,"padding":null,
 "added_tokens":[
  {"id":0,"special":true,"content":"[PAD]"},
  {"id":100,"special":true,"content":"[UNK]"},
  {"id":101,"special":true,"content":"[CLS]"},
  {"id":102,"special":true,"content":"[SEP]"},
  {"id":103,"special":true,"content":"[MASK]"}],
 "normalizer":{"type":"BertNormalizer","clean_text":true,"handle_chinese_chars":true,"strip_accents":null,"lowercase":true},
 "pre_tokenizer":{"type":"BertPreTokenizer"},
 "post_processor":{"type":"TemplateProcessing",
   "single":[{"SpecialToken":{"id":"[CLS]","type_id":0}},{"Sequence":{"id":"A","type_id":0}},{"SpecialToken":{"id":"[SEP]","type_id":0}}],
   "pair":[{"SpecialToken":{"id":"[CLS]","type_id":0}},{"Sequence":{"id":"A","type_id":0}},{"SpecialToken":{"id":"[SEP]","type_id":0}},{"Sequence":{"id":"B","type_id":1}},{"SpecialToken":{"id":"[SEP]","type_id":1}}]},
 "decoder":{"type":"WordPiece","prefix":"##","cleanup":true},
 "model":{"type":"WordPiece","unk_token":"[UNK]","continuing_subword_prefix":"##","vocab":{"[PAD]":0,"[UNK]":100,"[CLS]":101,"[SEP]":102,"[MASK]":103,"[unused0]":1}}}
JSON
  echo "   -> tokenizer.json (ŞABLON) YAZILDI: $HFREPO/blobs/$BLOB_HASH_TOKENIZER_JSON"
fi

if [ -n "${HF_SRC_VOCAB_TXT:-}" ] && [ -f "$HF_SRC_VOCAB_TXT" ]; then
  cp -f "$HF_SRC_VOCAB_TXT" "$HFREPO/blobs/$BLOB_HASH_VOCAB"
  echo "   -> vocab.txt KOPYALANDI: $HFREPO/blobs/$BLOB_HASH_VOCAB"
else
  cat > "$HFREPO/blobs/$BLOB_HASH_VOCAB" << "TXT"
[PAD]
[UNK]
[CLS]
[SEP]
[MASK]
the
of
and
to
a
in
is
it
you
that
TXT
  echo "   -> vocab.txt (MİNİMAL) YAZILDI: $HFREPO/blobs/$BLOB_HASH_VOCAB"
fi

if [ -n "${HF_SRC_MODEL_SAFE:-}" ] && [ -f "$HF_SRC_MODEL_SAFE" ]; then
  cp -f "$HF_SRC_MODEL_SAFE" "$HFREPO/blobs/$BLOB_HASH_MODEL"
  echo "   -> model.safetensors KOPYALANDI: $HFREPO/blobs/$BLOB_HASH_MODEL"
else
  dd if=/dev/zero of="$HFREPO/blobs/$BLOB_HASH_MODEL" bs=1m count=1 >/dev/null 2>&1
  echo "   -> model.safetensors (PLACEHOLDER) OLUŞTURULDU: $HFREPO/blobs/$BLOB_HASH_MODEL"
fi

if [ -n "${HF_SRC_MODEL_SAFE_ZIP:-}" ] && [ -f "$HF_SRC_MODEL_SAFE_ZIP" ]; then
  cp -f "$HF_SRC_MODEL_SAFE_ZIP" "$HFREPO/blobs/model.safetensors.zip"
fi

cp -f "$HFREPO/blobs/$BLOB_HASH_CONFIG"         "$HFREPO/blobs/config.json"
cp -f "$HFREPO/blobs/$BLOB_HASH_MODEL"          "$HFREPO/blobs/model.safetensors"
cp -f "$HFREPO/blobs/$BLOB_HASH_TOKENIZER_CFG"  "$HFREPO/blobs/tokenizer_config.json"
cp -f "$HFREPO/blobs/$BLOB_HASH_TOKENIZER_JSON" "$HFREPO/blobs/tokenizer.json"
cp -f "$HFREPO/blobs/$BLOB_HASH_VOCAB"          "$HFREPO/blobs/vocab.txt"

echo "$HF_SNAPSHOT_ID" > "$HFREPO/refs/main"

cd "$HFREPO/snapshots/$HF_SNAPSHOT_ID"
ln -sf "../../blobs/$BLOB_HASH_CONFIG"         config.json
ln -sf "../../blobs/$BLOB_HASH_MODEL"          model.safetensors
ln -sf "../../blobs/$BLOB_HASH_TOKENIZER_CFG"  tokenizer_config.json
ln -sf "../../blobs/$BLOB_HASH_TOKENIZER_JSON" tokenizer.json
ln -sf "../../blobs/$BLOB_HASH_VOCAB"          vocab.txt
cd - >/dev/null

echo
echo "📦 HF Repo Kuruldu:"
echo "  $HFREPO"
echo "  ├─ blobs/"
echo "  │   ├─ $BLOB_HASH_CONFIG            (config.json)"
echo "  │   ├─ $BLOB_HASH_MODEL             (model.safetensors)"
echo "  │   ├─ $BLOB_HASH_TOKENIZER_CFG     (tokenizer_config.json)"
echo "  │   ├─ $BLOB_HASH_TOKENIZER_JSON    (tokenizer.json)"
echo "  │   └─ $BLOB_HASH_VOCAB             (vocab.txt)"
echo "  ├─ refs/main -> $HF_SNAPSHOT_ID"
echo "  └─ snapshots/$HF_SNAPSHOT_ID/ -> blobs/* symlinkleri"

echo
echo "⚠️  NOT: tokenizer.json/vocab.txt/model.safetensors için ELİNİZDE TAM DOSYALAR VARSA"
echo "    aşağıdaki değişkenleri export edin ve scripti tekrar çalıştırın:"
echo "    HF_SRC_TOKENIZER_JSON=...</tokenizer.json>  HF_SRC_VOCAB_TXT=...</vocab.txt>  HF_SRC_MODEL_SAFE=...</model.safetensors>"
echo