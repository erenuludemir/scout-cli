export APP_ROOT="${APP_ROOT:-$(pwd)}"
export APP_DIR="${APP_DIR:-$APP_ROOT}"
export DOCKER_USERNAME="erenuludemir"
export DOCKER_PAT='dckr_pat_xxx'

/bin/bash -lc 'command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; eval "$(/opt/homebrew/bin/brew shellenv)"; brew update; brew install colima jq yq watch tmux || true'
/bin/bash -lc 'colima start --vm-type vz --vz-rosetta --cpu 4 --memory 6 --disk 25 --dns 1.1.1.1 --dns 8.8.8.8 || true'
docker context use colima

printf "%s" "$DOCKER_PAT" | docker login -u "$DOCKER_USERNAME" --password-stdin

cp -f "$APP_DIR/compose.yml" "$APP_DIR/compose.yml.bak.$(date +%s)" 2>/dev/null || true

yq -iy '
  .services["gli-container"].command = ["sh","-lc","python -m pip install -q --no-cache-dir '\''Flask==2.2.5'\'' '\''Werkzeug==2.2.3'\'' || true; exec python app.py"] |
  .services["gli-mainnet"].command   = ["sh","-lc","python -m pip install -q --no-cache-dir '\''Flask==2.2.5'\'' '\''Werkzeug==2.2.3'\'' || true; exec python app.py"] |
  .services["gli-sepolia"].command   = ["sh","-lc","python -m pip install -q --no-cache-dir '\''Flask==2.2.5'\'' '\''Werkzeug==2.2.3'\'' || true; exec python app.py"]
' "$APP_DIR/compose.yml"

docker compose -f "$APP_DIR/compose.yml" config
docker compose -f "$APP_DIR/compose.yml" up -d --force-recreate

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
for s in gli-container gli-mainnet gli-sepolia; do
  echo "==== $s ===="; docker logs --tail=120 "$s" | tail -n 60 || true
done

docker exec -it gli-container python - <<'PY'
from importlib.metadata import version
print("Flask", version("Flask"))
print("Werkzeug", version("Werkzeug"))
PY

cp -f "$APP_DIR/Dockerfile" "$APP_DIR/Dockerfile.bak.$(date +%s)" 2>/dev/null || true
cat > "$APP_DIR/Dockerfile" <<'DOCKER'
FROM python:3.10-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY . /app
RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir "Flask==2.2.5" "Werkzeug==2.2.3" && \
    if [ -f requirements.txt ]; then python -m pip install --no-cache-dir -r requirements.txt || true; fi && \
    if [ -f gli/requirements.txt ]; then python -m pip install --no-cache-dir -r gli/requirements.txt || true; fi && \
    if [ -f gli-app/requirements.txt ]; then python -m pip install --no-cache-dir -r gli-app/requirements.txt || true; fi
CMD ["python","app.py"]
DOCKER

append_pin(){ f="$1"; [ -f "$f" ] || return 0; grep -Qi '^Flask==' "$f" || printf "\nFlask==2.2.5\nWerkzeug==2.2.3\n" >> "$f"; }
append_pin "$APP_DIR/requirements.txt"
append_pin "$APP_DIR/gli/requirements.txt"
append_pin "$APP_DIR/gli-app/requirements.txt"

docker buildx create --name colima-builder --use >/dev/null 2>&1 || docker buildx use colima-builder
docker buildx build --platform linux/arm64 -t "${DOCKER_USERNAME}/gli-app:fixed" "$APP_DIR" --push

yq -iy '.services["gli-container"].image="'"${DOCKER_USERNAME}/gli-app:fixed"'"' "$APP_DIR/compose.yml"
yq -iy 'del(.services["gli-container"].command)' "$APP_DIR/compose.yml"
yq -iy '.services["gli-mainnet"].image="'"${DOCKER_USERNAME}/gli-app:fixed"'"' "$APP_DIR/compose.yml"
yq -iy 'del(.services["gli-mainnet"].command))' "$APP_DIR/compose.yml")
yq -iy '.services["gli-sepolia"].image="'"${DOCKER_USERNAME}/gli-app:fixed"'"' "$APP_DIR/compose.yml"
yq -iy 'del(.services["gli-sepolia"].command)' "$APP_DIR/compose.yml"

yq -iy '.' "$APP_DIR/compose.yml"

set +H

docker compose -f "$APP_DIR/compose.yml" config >/dev/null || { echo "[!] compose.yml parse edilemedi; dosyayı betikle baştan üretmeyi düşünün."; }

docker compose -f "$APP_DIR/compose.yml" up -d --force-recreate
docker compose -f "$APP_DIR/compose.yml" ps

for s in gli-container gli-mainnet gli-sepolia; do
  echo ">>>> $s"
  docker inspect $s --format 'Exit={{.State.ExitCode}} Health={{if .State.Health}}{{.State.Health.Status}}{{end}} Err={{.State.Error}}'
  docker logs --tail=200 $s | tail -n 80
done
docker exec -it gli-container python - <<'PY'
from importlib.metadata import version
print("Flask", version("Flask"))
print("Werkzeug", version("Werkzeug"))
import flask
app = flask.Flask(__name__)
@app.route("/")
def ok(): return "OK"
print("App import OK")
PY
