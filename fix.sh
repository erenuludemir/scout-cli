bash <<'EOS'
set -Eeuo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
hn="$(ulimit -Hn 2>/dev/null || echo 10240)"; hu="$(ulimit -Hu 2>/dev/null || echo 2048)"
set +e
[ "$hn" = "unlimited" ] && ulimit -n 65535 2>/dev/null || ulimit -n "$hn" 2>/dev/null
[ "$hu" = "unlimited" ] && ulimit -u 4096 2>/dev/null || ulimit -u "$hu" 2>/dev/null
set -e

if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)" || true
fi
export HOMEBREW_NO_AUTO_UPDATE=1
for p in postgresql@16 redis jq tmux node python; do
  brew list --versions "$p" >/dev/null 2>&1 || brew install "$p"
done
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"

BASE="$HOME/qai-borsa-platform"
SQL_DIR="$BASE/db/migrations"
SQL_FILE="$SQL_DIR/001_init_master.sql"
DB=qai
DBU=qaiuser
DBP=qaipass

mkdir -p "$BASE"/{frontend,backend-node/src,backend-python,db/migrations,ops}

cat > "$BASE/.env" <<'ENV'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=qai
DB_USER=qaiuser
DB_PASSWORD=qaipass
REDIS_HOST=localhost
REDIS_PORT=6379
NODE_API_PORT=8080
PY_API_PORT=8000
VITE_NODE_API=http://localhost:8080
VITE_PY_API=http://localhost:8000
JWT_SECRET=change_this_in_prod
ENV

brew services start postgresql@16 >/dev/null 2>&1 || true
brew services start redis >/dev/null 2>&1 || true
for i in $(seq 1 30); do pg_isready -q && break || sleep 1; done

cat > "$SQL_FILE" <<'SQL'
\set ON_ERROR_STOP on
SET client_min_messages TO WARNING;

-- run as superuser (brew macOS: current user)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='qaiuser') THEN
    CREATE ROLE qaiuser LOGIN PASSWORD 'qaipass';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='qai') THEN
    CREATE DATABASE qai OWNER qaiuser;
  END IF;
END$$;

\connect :DBNAME

SET client_min_messages TO WARNING;
BEGIN;
SELECT pg_advisory_lock(93841234);

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER SCHEMA public OWNER TO qaiuser;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT 'TABLE '||quote_ident(schemaname)||'.'||quote_ident(tablename) AS obj
             FROM pg_tables WHERE schemaname='public'
  LOOP EXECUTE 'ALTER '||r.obj||' OWNER TO qaiuser'; END LOOP;

  FOR r IN SELECT 'SEQUENCE '||quote_ident(schemaname)||'.'||quote_ident(sequencename) AS obj
             FROM pg_sequences WHERE schemaname='public'
  LOOP EXECUTE 'ALTER '||r.obj||' OWNER TO qaiuser'; END LOOP;
END$$;

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

CREATE TABLE IF NOT EXISTS accounts (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  asset TEXT NOT NULL,
  balance NUMERIC(32,8) NOT NULL DEFAULT 0
);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='uc_user_asset' AND conrelid='accounts'::regclass
  ) THEN
    ALTER TABLE accounts ADD CONSTRAINT uc_user_asset UNIQUE(user_id, asset);
  END IF;
END$$;
CREATE INDEX IF NOT EXISTS idx_accounts_user  ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_asset ON accounts(asset);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='order_side') THEN
    CREATE TYPE order_side AS ENUM('BUY','SELL');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  market TEXT NOT NULL,
  side order_side NOT NULL,
  price NUMERIC(32,8) NOT NULL CHECK (price > 0),
  qty   NUMERIC(32,8) NOT NULL CHECK (qty > 0),
  status TEXT NOT NULL DEFAULT 'OPEN',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_orders_user          ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_market_side   ON orders(market, side);
CREATE INDEX IF NOT EXISTS idx_orders_status_market ON orders(status, market);
CREATE INDEX IF NOT EXISTS idx_orders_created_at    ON orders(created_at);

CREATE TABLE IF NOT EXISTS trades (
  id BIGSERIAL PRIMARY KEY,
  buy_order_id  BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  sell_order_id BIGINT REFERENCES orders(id) ON DELETE SET NULL,
  market TEXT NOT NULL,
  price NUMERIC(32,8) NOT NULL,
  qty   NUMERIC(32,8) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_trades_market_time ON trades(market, created_at DESC);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='touch_updated_at') THEN
    CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $f$
    BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $f$ LANGUAGE plpgsql;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE event_object_table='orders' AND trigger_name='trg_orders_updated_at'
  ) THEN
    CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders
      FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS schema_migrations(
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP NOT NULL DEFAULT NOW()
);
INSERT INTO schema_migrations(version)
  SELECT '001_init_master'
  WHERE NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version='001_init_master');

SELECT pg_advisory_unlock(93841234);
COMMIT;
SQL

psql -v DBNAME="$DB" -v ON_ERROR_STOP=1 -q -d postgres -f "$SQL_FILE" >/dev/null

cat > "$BASE/backend-node/package.json" <<'JSON'
{
  "name": "qai-backend-node",
  "type": "module",
  "version": "0.1.0",
  "scripts": { "dev": "node src/index.js", "start": "node src/index.js" },
  "dependencies": {
    "bcryptjs": "^2.4.3", "cors": "^2.8.5", "dotenv": "^16.4.5",
    "express": "^4.19.2", "ioredis": "^5.4.1", "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3", "socket.io": "^4.7.5"
  }
}
JSON

cat > "$BASE/backend-node/src/index.js" <<'JS'
import 'dotenv/config';
import express from 'express';
import http from 'http';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import pkg from 'pg';
import { Server as IOServer } from 'socket.io';
import Redis from 'ioredis';

const app = express();
app.use(cors());
app.use(express.json());

const { DB_HOST,DB_PORT,DB_NAME,DB_USER,DB_PASSWORD, NODE_API_PORT, JWT_SECRET, REDIS_HOST, REDIS_PORT } = process.env;
const { Pool } = pkg;
const pool = new Pool({ host:DB_HOST, port:DB_PORT, database:DB_NAME, user:DB_USER, password:DB_PASSWORD });
const redis = new Redis({ host: REDIS_HOST, port: Number(REDIS_PORT||6379) });

app.get('/api/health', (_req,res)=>res.json({ok:true}));

app.post('/api/auth/register', async (req,res)=>{
  const { email,password } = req.body ?? {};
  if(!email||!password) return res.status(400).json({error:'email/password'});
  const hash = await bcrypt.hash(password,10);
  try{
    await pool.query('INSERT INTO users(email,password_hash) VALUES($1,$2)',[email,hash]);
    await pool.query(
      "INSERT INTO accounts(user_id,asset,balance) SELECT id,'USDT',1000 FROM users WHERE email=$1 ON CONFLICT DO NOTHING",
      [email]
    );
    res.json({ok:true});
  }catch(e){ res.status(400).json({error:'exists?',detail:e.message}); }
});

app.post('/api/auth/login', async (req,res)=>{
  const { email,password } = req.body ?? {};
  const { rows } = await pool.query('SELECT * FROM users WHERE email=$1',[email]);
  if(!rows[0]) return res.status(401).json({error:'invalid'});
  const good = await bcrypt.compare(password, rows[0].password_hash);
  if(!good) return res.status(401).json({error:'invalid'});
  const token = jwt.sign({ uid: rows[0].id, email }, JWT_SECRET, { expiresIn:'7d' });
  res.json({ token });
});

function auth(req,res,next){
  const hdr = req.headers.authorization || '';
  const token = hdr.startsWith('Bearer ') ? hdr.slice(7) : null;
  try{ req.user = jwt.verify(token, JWT_SECRET); next(); }
  catch{ res.status(401).json({error:'unauthorized'}); }
}

app.get('/api/me/accounts', auth, async (req,res)=>{
  const { rows } = await pool.query('SELECT asset,balance FROM accounts WHERE user_id=$1',[req.user.uid]);
  res.json(rows);
});

app.post('/api/orders', auth, async (req,res)=>{
  const { market,side,price,qty } = req.body ?? {};
  const { rows } = await pool.query(
    `INSERT INTO orders(user_id,market,side,price,qty) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [req.user.uid, market, side, price, qty]
  );
  await redis.lpush('match_queue', JSON.stringify(rows[0]));
  res.json(rows[0]);
});

app.get('/api/orders', auth, async (req,res)=>{
  const { rows } = await pool.query('SELECT * FROM orders WHERE user_id=$1 ORDER BY id DESC LIMIT 50',[req.user.uid]);
  res.json(rows);
});

const server = http.createServer(app);
const io = new IOServer(server, { cors:{origin:'*'} });

io.on('connection',(socket)=>{ socket.emit('welcome',{t:Date.now()}); });

async function loop(){
  try{
    const item = await redis.rpop('match_queue');
    if(item){
      const ord = JSON.parse(item);
      await pool.query("UPDATE orders SET status='FILLED' WHERE id=$1",[ord.id]);
      await pool.query(
        `INSERT INTO trades(buy_order_id,sell_order_id,market,price,qty)
         VALUES($1,$2,$3,$4,$5)`,
        [ ord.side==='BUY'?ord.id:null, ord.side==='SELL'?ord.id:null, ord.market, ord.price, ord.qty ]
      );
      io.emit('trade',{ market:ord.market, price:ord.price, qty:ord.qty, ts:Date.now() });
    }
  }finally{ setTimeout(loop,250); }
}
loop();

server.listen(process.env.NODE_API_PORT||8080, ()=> console.log('Node API on', process.env.NODE_API_PORT||8080));
JS

cat > "$BASE/backend-python/requirements.txt" <<'REQ'
fastapi==0.111.0
uvicorn==0.30.0
python-dotenv==1.0.1
REQ

cat > "$BASE/backend-python/main.py" <<'PY'
import os
from fastapi import FastAPI
from dotenv import load_dotenv
load_dotenv()
app = FastAPI()
@app.get("/api/ai/ping")
def ping(): return {"ok": True}
PY

cat > "$BASE/backend-python/package.json" <<'JSON'
{ "name":"qai-backend-python-wrapper","private":true,
  "scripts":{ "dev":"sh -lc \"python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt && uvicorn main:app --host 0.0.0.0 --port ${PY_API_PORT:-8000} --reload\"" }
}
JSON

cat > "$BASE/frontend/package.json" <<'JSON'
{
  "name":"qai-frontend","version":"0.1.0","private":true,"type":"module",
  "scripts":{"dev":"vite","start":"vite","build":"vite build","preview":"vite preview --port 5173"},
  "dependencies":{"react":"^18.3.1","react-dom":"^18.3.1"},
  "devDependencies":{"vite":"^5.3.4"}
}
JSON

cat > "$BASE/frontend/vite.config.js" <<'JS'
export default { server:{ host:true, port:5173 } }
JS
cat > "$BASE/frontend/.env.local" <<'ENV'
VITE_NODE_API=http://localhost:8080
VITE_PY_API=http://localhost:8000
ENV
cat > "$BASE/frontend/index.html" <<'HTML'
<!doctype html><html lang="tr"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>QAI Exchange</title></head><body style="margin:0;background:#0b0f1a;font-family:ui-sans-serif,system-ui;"><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>
HTML
mkdir -p "$BASE/frontend/src"
cat > "$BASE/frontend/src/main.jsx" <<'JS'
import React from 'react'; import { createRoot } from 'react-dom/client'; import App from './App.jsx';
createRoot(document.getElementById('root')).render(<App />)
JS
cat > "$BASE/frontend/src/App.jsx" <<'JSX'
import { useEffect, useState } from 'react'
const NODE = import.meta.env.VITE_NODE_API, PY = import.meta.env.VITE_PY_API
export default function App(){
  const [health,setHealth]=useState(null),[ai,setAi]=useState(null),[auth,setAuth]=useState({email:'',pass:'',token:''}),[orders,setOrders]=useState([])
  useEffect(()=>{ fetch(`${NODE}/api/health`).then(r=>r.json()).then(setHealth); fetch(`${PY}/api/ai/ping`).then(r=>r.json()).then(setAi) },[])
  async function register(){ await fetch(`${NODE}/api/auth/register`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:auth.email,password:auth.pass})}); alert('Kayıt denendi, şimdi giriş yapın.') }
  async function login(){ const r=await fetch(`${NODE}/api/auth/login`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:auth.email,password:auth.pass})}); const j=await r.json(); if(j.token) setAuth(a=>({...a,token:j.token})) }
  async function meAccounts(){ const r=await fetch(`${NODE}/api/me/accounts`,{headers:{Authorization:`Bearer ${auth.token}`}}); alert(await r.text()) }
  async function placeOrder(){ const r=await fetch(`${NODE}/api/orders`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${auth.token}`},body:JSON.stringify({market:'BTC-USDT',side:'BUY',price:'65000',qty:'0.001'})}); alert(await r.text()) }
  async function listOrders(){ const r=await fetch(`${NODE}/api/orders`,{headers:{Authorization:`Bearer ${auth.token}`}}); setOrders(await r.json()) }
  return (<div style={{color:'#fff',padding:'24px'}}><h2>QAI Exchange</h2>
    <div style={{display:'grid',gap:12,gridTemplateColumns:'repeat(2,minmax(0,1fr))'}}>
      <div style={{background:'#12172a',padding:16,borderRadius:10}}><h3>Durum</h3><pre>Node: {JSON.stringify(health)}</pre><pre>AI: {JSON.stringify(ai)}</pre></div>
      <div style={{background:'#12172a',padding:16,borderRadius:10}}><h3>Auth</h3>
        <input placeholder="email" value={auth.email} onChange={e=>setAuth(a=>({...a,email:e.target.value}))} style={{width:'100%',padding:8,marginBottom:6}}/>
        <input placeholder="password" type="password" value={auth.pass} onChange={e=>setAuth(a=>({...a,pass:e.target.value}))} style={{width:'100%',padding:8,marginBottom:6}}/>
        <div style={{display:'flex',gap:8}}>
          <button onClick={register}>Kayıt</button><button onClick={login}>Giriş</button>
        </div>
        <div style={{marginTop:8,fontSize:12,wordBreak:'break-all'}}>Token: {auth.token?auth.token.slice(0,32)+'…':'(yok)'}</div>
        <div style={{display:'flex',gap:8,marginTop:8}}>
          <button onClick={meAccounts} disabled={!auth.token}>Hesaplarım</button>
          <button onClick={placeOrder} disabled={!auth.token}>Emir Gönder</button>
          <button onClick={listOrders} disabled={!auth.token}>Emirlerim</button>
        </div>
      </div>
      <div style={{gridColumn:'1 / -1',background:'#12172a',padding:16,borderRadius:10}}><h3>Emirler</h3><pre style={{whiteSpace:'pre-wrap'}}>{JSON.stringify(orders,null,2)}</pre></div>
    </div></div>)
}
JSX

( cd "$BASE/frontend" && npm install >/dev/null )
( cd "$BASE/backend-node" && npm install >/dev/null )
( cd "$BASE/backend-python" && npm install >/dev/null )
cat > "$BASE/package.json" <<'JSON'
{ "name":"qai-borsa-platform","private":true,"scripts":{ "dev:tmux":"bash ops/dev-tmux.sh" }, "dependencies":{} }
JSON

mkdir -p "$BASE/ops"
cat > "$BASE/ops/dev-tmux.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; source "$BASE_DIR/.env"; set +a
session="qai"
tmux has-session -t "$session" 2>/dev/null && tmux kill-session -t "$session" || true
tmux new-session -d -s "$session" -c "$BASE_DIR/backend-node" "node src/index.js"
tmux split-window -h -t "$session":0 -c "$BASE_DIR/backend-python" "sh -lc 'python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt >/dev/null && uvicorn main:app --host 0.0.0.0 --port ${PY_API_PORT:-8000} --reload'"
tmux split-window -v -t "$session":0.1 -c "$BASE_DIR/frontend" "npm run dev"
tmux select-layout tiled
echo "[LOGS] tmux attach -t $session"
tmux attach -t "$session"
SH
chmod +x "$BASE/ops/dev-tmux.sh"

set -a; source "$BASE/.env"; set +a
"$BASE/ops/dev-tmux.sh"
EOS