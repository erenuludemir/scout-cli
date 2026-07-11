#!/usr/bin/env bash
# qai_finish_and_render.sh
# One-shot finisher for steps 12-17 (exact order preserved) + diagram compilation.
set -euo pipefail

ROOT_FIXED="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$ROOT_FIXED"
if [[ ! -d "$ROOT" ]]; then
  ROOT="$SCRIPT_DIR"
fi
MASTER_COMPOSE="$ROOT/compose.master.yml"
MAIN_COMPOSE="$ROOT/compose.yml"
MAIN_OVERRIDE_COMPOSE="$ROOT/compose.override.yml"
COMPOSE_FILE_TARGET="$MAIN_COMPOSE:$MAIN_OVERRIDE_COMPOSE"
ENV_FILE="$ROOT/.env"
OUT_DIR="$ROOT/diagrams_out"
SRC_DIR="$ROOT/diagrams_src"

# ====== Flags ======
MAINNET="false"
[[ "${1:-}" == "--mainnet" ]] && MAINNET="true"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING:$1" >&2
    exit 1
  }
}

need docker
need curl
need python3

if [[ ! -d "$ROOT" ]]; then
  echo "ROOT not found: $ROOT" >&2
  exit 1
fi

# ====== Step 12 ======
echo "12) [ACTION REQUIRED] Rotate/Remove EXPOSED MAINNET KEYS"
echo "    - Binance > API Management: DELETE the exposed key pair now."
echo "    - Create new keys ONLY when truly needed. Do NOT paste keys into terminals."
if [[ "$MAINNET" == "true" ]]; then
  read -r -p ">>> Type 'ROTATED' after you revoke the old keys (or Ctrl+C to abort): " ROTATED_ACK || true
  if [[ "${ROTATED_ACK:-}" != "ROTATED" ]]; then
    echo "    - Keys not confirmed as rotated; staying SAFE on TESTNET."
    MAINNET="false"
  else
    echo "    - Keys rotation acknowledged."
  fi
else
  echo "    - Skipping rotation prompt (staying on TESTNET)."
fi
echo

# ====== Step 13 ======
echo "13) Fix VS Code compose IPAM error (Config expected array, got null)..."
if [[ -f "$MASTER_COMPOSE" ]]; then
  cp -p "$MASTER_COMPOSE" "$MASTER_COMPOSE.bak.$(date +%Y%m%d_%H%M%S)"
  if command -v yq >/dev/null 2>&1; then
    yq -i '
      .networks.default |= (. // {}) |
      .networks.default.driver = "bridge" |
      .networks.default.ipam = {"driver":"default","config":[]}
    ' "$MASTER_COMPOSE"
    echo "    - Patched $MASTER_COMPOSE with yq."
  else
    echo "    - yq not found. Please adjust $MASTER_COMPOSE manually under networks: default:"
    printf "%s\n" "      driver: bridge" "      ipam:" "        driver: default" "        config: []"
  fi
else
  echo "    - $MASTER_COMPOSE not found; skipping IPAM patch."
fi
echo

# ====== Step 14 ======
echo "14) Point tools at the correct compose files & remove conflicting env..."
launchctl unsetenv COMPOSE_FILE 2>/dev/null || true
unset COMPOSE_FILE || true
echo "    - COMPOSE_FILE unset (GUI + shell). Compose target => $COMPOSE_FILE_TARGET"
echo

# ====== Step 15 ======
echo "15) Stop stray, non-compose containers (80/6379 test helpers)..."
for NAME in condescending_boyd adoring_jemison; do
  ID="$(docker ps -aqf name="^${NAME}$" || true)"
  if [[ -n "${ID}" ]]; then
    docker rm -f "${ID}" && echo "    - Removed ${NAME}"
  else
    echo "    - ${NAME} not present"
  fi
done
echo

# ====== Step 17 ======
echo "17) Decide & apply environment with safety gate..."
if [[ -f "$ENV_FILE" ]]; then
  cp -p "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
  if [[ "$MAINNET" == "true" ]]; then
    /usr/bin/sed -i '' -e 's/^BINANCE_TESTNET=.*/BINANCE_TESTNET=0/' "$ENV_FILE" || true
    /usr/bin/sed -i '' -e 's/^DEMO_MODE=.*/DEMO_MODE=0/' "$ENV_FILE" || true
    export LIVE_TRADING_I_UNDERSTAND_RISKS=YES
    echo "    - MAINNET flags set (BINANCE_TESTNET=0, DEMO_MODE=0)."
    echo "    - LIVE_TRADING_I_UNDERSTAND_RISKS=YES exported (this shell)."
  else
    /usr/bin/sed -i '' -e 's/^BINANCE_TESTNET=.*/BINANCE_TESTNET=1/' "$ENV_FILE" || true
    /usr/bin/sed -i '' -e 's/^DEMO_MODE=.*/DEMO_MODE=1/' "$ENV_FILE" || true
    echo "    - TESTNET/DEMO enforced (BINANCE_TESTNET=1, DEMO_MODE=1)."
  fi
else
  echo "    - $ENV_FILE not found; skipping environment update."
fi
echo

# ====== Step 16 ======
echo "16) Recreate stack cleanly on Colima (compose @ ROOT)..."
docker context use colima >/dev/null 2>&1 || true
(
  cd "$ROOT"
  docker compose -f "$MAIN_COMPOSE" -f "$MAIN_OVERRIDE_COMPOSE" up -d --force-recreate
)
echo "    - Stack restarted."
echo

echo "16b) Health checks..."
TRADER="$(curl -fsS http://127.0.0.1:5003/health || curl -fsS http://127.0.0.1:8080/health || true)"
USDT="$(curl -fsS http://127.0.0.1:5003/usdt/ || curl -fsS http://127.0.0.1:8000/health || true)"
echo "    - Trader  : ${TRADER:-UNAVAILABLE}"
echo "    - USDT    : ${USDT:-UNAVAILABLE}"
echo

# ====== Diagrams compile (artifacts; not counted against 12-17) ======
echo "D) Compile blockdiag/rackdiag diagrams to PNG+SVG..."
mkdir -p "$OUT_DIR" "$SRC_DIR"

# Ensure blockdiag & friends on PATH for macOS user installs
export PATH="$HOME/Library/Python/3.11/bin:$HOME/Library/Python/3.10/bin:$HOME/Library/Python/3.9/bin:$PATH"

# Install if missing
need_install=""
command -v blockdiag >/dev/null 2>&1 || need_install="yes"
command -v rackdiag >/dev/null 2>&1 || need_install="yes"
if [[ -n "${need_install}" ]]; then
  echo "    - Installing blockdiag & rackdiag (user scope)..."
  python3 -m pip install --user --quiet blockdiag actdiag seqdiag nwdiag rackdiag
fi

# Write sources from your message
cat > "$SRC_DIR/rmt_encoder_chain.diag" <<'DIAG'
blockdiag rmt_encoder_chain {
    orientation = portrait;
    default_fontsize = 14;
    node_width = 160;
    node_height = 40;
    span_width = 80;
    span_height = 40;

    new [label = "New", shape = "beginpoint"];
    init [label = "Init"];
    encoder_a [label = "Encoder A"];
    encoder_b [label = "Encoder B"];
    other_encoder [shape = "dots"];
    yield [label = "Yield", shape = "endpoint"];

    new -> init [folded];
    init -> encoder_a [thick];
    encoder_a <-> yield [folded, thick, color = "green", label = "full"];
    encoder_a -> encoder_b [thick];
    encoder_b <-> yield [color = "green", thick, label = "full"];
    encoder_b -> other_encoder [style = "dotted"];
    encoder_a, encoder_b -> init [thick, color = red, label = "reset"];
    other_encoder -> init [thick, color = red, label = "finish"];
}
DIAG

cat > "$SRC_DIR/ethernet_data_frame.diag" <<'DIAG'
rackdiag ethernet_data_frame {
    node_width = 500;
    default_fontsize = 15;
    ascending;
    8U;
    description = "Ethernet Data Frame Format";
    1: Preamble (7 Bytes) [color = lightgrey];
    2: Start-of-Frame Delimiter (1 Byte) [color = lightgrey];
    3: Destination Address (6 Bytes) [color = lightblue];
    4: Source Address (6 Bytes) [color = lightblue];
    5: Type / Length (2 Bytes) [color = lightyellow];
    6: Payload (0 ~ 1500 Bytes) [2U];
    6: Pad (if necessary) [2U];
    8: Frame Check Sequence (4 Bytes) [color = lightgrey];
}
DIAG

cat > "$SRC_DIR/state_transition_diagram.diag" <<'DIAG'
blockdiag state_transition_diagram {
    orientation = landscape;
    default_fontsize = 18;
    node_width = 180;
    node_height = 40;
    span_width = 100;
    span_height = 40;

    bus_off [label = "Bus-Off"];
    recovering [label = "Recovering"];
    uninstalled [label = "Uninstalled"];
    stopped [label = "Stopped"];
    running [label = "Running"];
    app_start[label = "Entry", shape = beginpoint];

    bus_off -> uninstalled [folded, thick, fontsize = 14, label = "F"];
    bus_off -> recovering [thick, fontsize = 14, label = "G"];
    recovering -> stopped [folded, thick, color = blue, fontsize = 14, label = "H"];

    uninstalled <-> stopped [thick, fontsize = 14, label = "A/B"];
    stopped <-> running [thick, fontsize = 14, label = "C/D"];
    running -> bus_off [folded, thick, color = red, fontsize = 14, label = "E"];

    app_start -> uninstalled [folded, style = dashed]
}
DIAG

cat > "$SRC_DIR/controller_signals_diagram.diag" <<'DIAG'
blockdiag controller_signals_diagram {
    orientation = portrait;
    span_width = 80;

    twai[label = "TWAI Controller", fontsize = 15, shape = roundedbox];
    tx[label = "TX", shape = endpoint];
    rx[label = "RX", shape = endpoint];
    bus_off[label = "BUS-OFF", shape = endpoint];
    clkout[label = "CLKOUT", shape = endpoint];

    hide1 [shape = none]; hide2 [shape = none]; hide3 [shape = none]; hide4 [shape = none];

    group { orientation = portrait; color = none; twai; }
    group { orientation = portrait; color = none; tx; rx; bus_off; clkout; }
    group { orientation = portrait; color = none; label = "GPIO Matrix"; fontsize = 20; shape = line; hide1; hide2; hide3; hide4; }

    twai -> tx [folded];
    twai -> rx [folded, dir = none];
    twai -> bus_off [folded];
    twai -> clkout [folded];

    tx -> hide1 [folded];
    rx <- hide2 [folded];
    bus_off -> hide3 [folded, label = "Optional"];
    clkout -> hide4 [folded, label = "Optional"];
}
DIAG

cat > "$SRC_DIR/i2c_command_link_master_read.diag" <<'DIAG'
blockdiag i2c-command-link-master-read {
    span_width = 5; span_height = 5; node_height = 25; default_group_color = lightgrey;
    class spacer [shape=none, width=10]; class cmdlink [colwidth=2, width=180]; class cjoint [shape=none, width=40];

    0 -- a0 --                         f0 [style=none];
    1 -- a1 -- b1 -- c1 -- d1 -- e1 -- f1 -- g1 -- h1 -- i1 -- j1 [style=none];
    2 -- a2 -- b2 -- c2 -- d2 -- e2 -- f2 -- g2 -- h2 -- i2  [style=none];
    3 -- a3 --             d3 --       f3 --       h3 [style=none];
    4 -- a4 [style=none]; 5 -- a5 [style=none];
    6 -- a6 --       c6 [style=none];
    7 -- a7 --       c7 -- d7 [style=none];
    8 -- a8 --       c8 --              f8 [style=none];
    9 -- a9 --       c9 --                         h9 [style=none];
    10 -- a10 --     c10 --                                    j10 [style=none];
    11 -- a11 [style=none]; 12 -- a12 [style=none];

    3, a3, d3, f3, h3 [shape=none, height=5];

    0 [class=spacer]; a0 [shape=none, colwidth=5]; f0 [shape=note, colwidth=2];
    1 [class=spacer]; a1 [shape=none]; b1; c1 [width=40]; e1 [shape=none, width=30]; f1 [shape=none]; g1 [width=30]; h1 [shape=none]; i1 [width=30]; j1 [width=40];
    2 [class=spacer]; a2 [shape=none]; b2; c2 [class=cjoint]; d2 [shape=none]; e2 [width=30]; g2 [shape=none, width=30]; i2 [shape=none, width=30];
    3 [class=spacer]; a3 [shape=none, colwidth=3]; d3 [colwidth=2]; f3 [colwidth=2]; h3 [colwidth=2];
    4 [class=spacer]; a4 [class=cmdlink]
    5 [class=spacer]; a5 [class=cmdlink];
    6 [class=spacer]; a6 [class=cmdlink]; c6 [class=cjoint]; a6 -- c6 [style=solid]; c6 -- c2 -> c1 [folded];
    7 [class=spacer]; a7 [class=cmdlink]; c7 [class=cjoint]; d7 [shape=none, colwidth=2]; a7 -- c7 -- d7 [style=solid]; d7 -> d3 [folded];
    8 [class=spacer]; a8 [class=cmdlink]; c8 [class=cjoint, colwidth=3]; f8 [shape=none, colwidth=2]; a8 -- c8 -- f8 [style=solid]; f8 -> f3 [folded];
    9 [class=spacer]; a9 [class=cmdlink]; c9 [class=cjoint, colwidth=5]; h9 [shape=none, colwidth=2]; a9 -- c9 -- h9 [style=solid]; h9 -> h3 [folded];
    10 [class=spacer]; a10 [class=cmdlink]; c10 [class=cjoint, colwidth=7]; j10 [shape=none, width=40]; a10 -- c10 -- j10 [style=solid]; j10 -> j1 [folded];
    11 [class=spacer]; a11 [class=cmdlink]; 12 [class=spacer]; a12 [class=cmdlink];

    f0 [label="Data (n-1) times", shape=note, color=yellow];
    b1 [label=Master, shape=note, color=lightyellow]; c1 [label=START]; d1 [label="Slave Address"]; g1 [label=ACK]; i1 [label=NAK]; j1 [label=STOP];
    b2 [label=Slave, shape=note, color=lightyellow]; e2 [label=ACK]; f2 [label=Data]; h2 [label=Data];
    a4 [shape=note, label=Commands, color=yellow];
    a5 [label="cmd = i2c_cmd_link_create()", numbered = 1];
    a6 [label="i2c_master_start(cmd)", numbered = 2];
    a7 [label="i2c_master_write_byte(cmd, Address, ACK)", numbered = 3];
    a8 [label="i2c_master_read(Data, n-1, ACK)", numbered = 4];
    a9 [label="i2c_master_read(Data, 1, NAK)", numbered = 5];
    a10 [label="i2c_master_stop(cmd)", numbered = 6];
    a11 [label="i2c_master_cmd_begin(I2c_port, cmd, wait)", numbered = 7];
    a12 [label="i2c_cmd_link_delete(cmd)", numbered = 8];

    group { d1; e1; } group { d2; e2; d3; }
    group { f1; g1;}  group { f2; g2; f3; }
    group { h1; i1; } group { h2; i2; h3; }
}
DIAG

cat > "$SRC_DIR/i2c_command_link_master_write.diag" <<'DIAG'
blockdiag i2c-command-link-master-write {
    span_width = 5; span_height = 5; node_height = 25; default_group_color = lightgrey;
    class spacer [shape=none, width=10]; class cmdlink [colwidth=2, width=180]; class cjoint [shape=none, width=40];

    0 -- a0 --                         f0 [style=none];
    1 -- a1 -- b1 -- c1 -- d1 -- e1 -- f1 -- g1 -- h1 [style=none];
    2 -- a2 -- b2 -- c2 -- d2 -- e2 -- f2 -- g2 [style=none];
    3 -- a3 --             d3 --       f3 [style=none];
    4 -- a4 [style=none]; 5 -- a5 [style=none];
    6 -- a6 --       c6 [style=none];
    7 -- a7 --       c7 -- d7 [style=none];
    8 -- a8 --       c8 --              f8 [style=none];
    9 -- a9 --       c9 --                         h9 [style=none];
    10 -- a10 [style=none]; 11 -- a11 [style=none];

    3, a3, d3, f3 [shape=none, height=5];

    0 [class=spacer]; a0 [shape=none, colwidth=5]; f0 [shape=note, colwidth=2];
    1 [class=spacer]; a1 [shape=none]; b1; c1 [width=40]; e1 [shape=none, width=30]; g1 [shape=none, width=30]; h1 [width=40];
    2 [class=spacer]; a2 [shape=none]; b2; c2 [class=cjoint]; d2 [shape=none]; e2 [width=30]; f2 [shape=none]; g2 [width=30];
    3 [class=spacer]; a3 [shape=none, colwidth=3]; d3 [colwidth=2]; f3 [colwidth=2];
    4 [class=spacer]; a4 [class=cmdlink]
    5 [class=spacer]; a5 [class=cmdlink];
    6 [class=spacer]; a6 [class=cmdlink]; c6 [class=cjoint]; a6 -- c6 [style=solid]; c6 -- c2 -> c1 [folded];
    7 [class=spacer]; a7 [class=cmdlink]; c7 [class=cjoint]; d7 [shape=none, colwidth=2]; a7 -- c7 -- d7 [style=solid]; d7 -> d3 [folded];
    8 [class=spacer]; a8 [class=cmdlink]; c8 [class=cjoint, colwidth=3]; f8 [shape=none, colwidth=2]; a8 -- c8 -- f8 [style=solid]; f8 -> f3 [folded];
    9 [class=spacer]; a9 [class=cmdlink]; c9 [class=cjoint, colwidth=5]; h9 [shape=none, width=40]; a9 -- c9 -- h9 [style=solid]; h9 -> h1 [folded];
    10 [class=spacer]; a10 [class=cmdlink]; 11 [class=spacer]; a11 [class=cmdlink];

    f0 [label="Data n times", shape=note, color=yellow];
    b1 [label=Master, shape=note, color=lightyellow]; c1 [label=START]; d1 [label="Slave Address"]; f1 [label=Data]; h1 [label=STOP];
    b2 [label=Slave, shape=note, color=lightyellow]; e2 [label=ACK]; g2 [label=ACK];
    a4 [shape=note, label=Commands, color=yellow];
    a5 [label="cmd = i2c_cmd_link_create()", numbered = 1];
    a6 [label="i2c_master_start(cmd)", numbered = 2];
    a7 [label="i2c_master_write_byte(cmd, Address, ACK)", numbered = 3];
    a8 [label="i2c_master_write(Data, n, ACK)", numbered = 4];
    a9 [label="i2c_master_stop(cmd)", numbered = 5];
    a10 [label="i2c_master_cmd_begin(I2c_port, cmd, wait)", numbered = 6];
    a11 [label="i2c_cmd_link_delete(cmd)", numbered = 7];

    group { d1; e1; } group { d2; e2; d3; }
    group { f1; g1;}  group { f2; g2; f3; }
}
DIAG

# Render all *.diag -> PNG + SVG
shopt -s nullglob
for f in "$SRC_DIR"/*.diag; do
  base="$(basename "$f" .diag)"
  if [[ "$base" == "ethernet_data_frame" ]]; then
    cmd="rackdiag"
  else
    cmd="blockdiag"
  fi
  echo "    - Rendering $base via $cmd..."
  "$cmd" -T svg "$f" -o "$OUT_DIR/$base.svg"
  "$cmd" -T png "$f" -o "$OUT_DIR/$base.png"
done
echo "    - Diagrams output => $OUT_DIR"
echo

# ====== Connection Points ======
echo "=== Connection points ==="
echo "    - Docker context      : colima"
echo "    - Compose files       : $MAIN_COMPOSE + $MAIN_OVERRIDE_COMPOSE"
echo "    - Master compose      : $MASTER_COMPOSE"
echo "    - Host ports          : gateway=5003, dex=8080, usdt=8000"
echo "    - Binance Base URLs   : testnet=https://testnet.binance.vision | mainnet=https://api.binance.com"
echo

# ====== Summary ======
echo "=== Summary ==="
echo "    Completed earlier      : 11/17"
if [[ "$MAINNET" == "true" ]]; then
  if [[ "${ROTATED_ACK:-}" == "ROTATED" ]]; then
    echo "    Step 12 (keys)         : Marked by you as ROTATED"
  else
    echo "    Step 12 (keys)         : Pending your manual rotation"
  fi
fi
echo "    Executed now (13-17)   : Applied (see logs above)."
echo "    Diagram artifacts      : Compiled to PNG+SVG under $OUT_DIR"
echo "    Final target           : ROOT=$ROOT"
echo "=================================================================="
