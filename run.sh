#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Likha Pet — Dev Environment Startup Script
#
#  Starts:
#    1. Firebase Emulator Suite (Firestore :8090 · Auth :9099 · UI :4000)
#    2. Express API server     (prototype hatchery server  :3000)
#    3. Webpack dev server     (Phaser client              :8080)
#    4. Dart battle engine     (offline demo run, then exits)
#
#  Usage:
#    chmod +x run.sh
#    ./run.sh              — start everything
#    ./run.sh --no-client  — skip webpack (faster, no browser UI)
#    ./run.sh --engine-only — only run the Dart battle engine demo
#
#  Stop: Ctrl+C — script traps SIGINT and kills all child processes cleanly.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Ports ─────────────────────────────────────────────────────────────────────
FIREBASE_UI_PORT=4000
FIRESTORE_PORT=8090
AUTH_PORT=9099
FUNCTIONS_PORT=5001
SERVER_PORT=3000
CLIENT_PORT=8080

# Firebase demo project — works without a real Firebase account
FIREBASE_PROJECT="demo-likha-pet"

# ── Flags ─────────────────────────────────────────────────────────────────────
START_CLIENT=true
ENGINE_ONLY=false
for arg in "$@"; do
  case $arg in
    --no-client)   START_CLIENT=false ;;
    --engine-only) ENGINE_ONLY=true   ;;
  esac
done

# ── Process registry (for clean shutdown) ─────────────────────────────────────
PIDS=()

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${BOLD}[likha-pet]${NC} $*"; }
ok()      { echo -e "${GREEN}  ✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()     { echo -e "${RED}  ✘${NC}  $*"; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}"; }

banner() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║          LIKHA PET  —  Dev Environment                  ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# Wait until a TCP port is accepting connections (max 45s)
wait_for_port() {
  local port=$1
  local label=$2
  local elapsed=0
  printf "  ⏳ Waiting for %s on :%s " "$label" "$port"
  until nc -z localhost "$port" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    printf "."
    if [ $elapsed -ge 45 ]; then
      echo ""
      err "$label did not become ready on :$port within 45s"
      err "Check the log: cat $SCRIPT_DIR/.emulator.log"
      exit 1
    fi
  done
  echo ""
  ok "$label is ready on :$port"
}

# Kill all tracked processes and their process groups
cleanup() {
  echo ""
  section "Shutting down"
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null || true
      ok "Stopped process $pid"
    fi
  done
  pkill -f "firebase emulators" 2>/dev/null || true
  echo ""
  log "All services stopped. Goodbye."
}
trap cleanup EXIT INT TERM

require() {
  local cmd=$1
  local install_hint=$2
  if ! command -v "$cmd" &>/dev/null; then
    err "'$cmd' not found. $install_hint"
    exit 1
  fi
  ok "$cmd  →  $(command -v "$cmd")"
}

# ─────────────────────────────────────────────────────────────────────────────
#  SCRIPT ROOT
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Keep Home > Mechanics markdown in sync with the root source file.
"$SCRIPT_DIR/sync_mechanics.sh"

# ─────────────────────────────────────────────────────────────────────────────
#  1. BANNER + --engine-only fast path
# ─────────────────────────────────────────────────────────────────────────────
banner

if $ENGINE_ONLY; then
  section "Battle Engine Demo (--engine-only)"
  require dart "Install from https://dart.dev/get-dart"
  echo ""
  cd battle_engine
  dart run bin/main.dart
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
#  2. JAVA 21+ RESOLUTION
#
#  Firebase emulator requires Java 21+.
#  Strategy: check if JAVA_HOME already points to 21+; if not, auto-detect
#  common Homebrew install paths before giving up.
# ─────────────────────────────────────────────────────────────────────────────
section "Resolving Java 21+"

resolve_java21() {
  # Candidate paths — Homebrew on Apple Silicon and Intel
  local candidates=(
    "/opt/homebrew/opt/openjdk@21/bin/java"   # Homebrew ARM (M1/M2/M3)
    "/usr/local/opt/openjdk@21/bin/java"      # Homebrew Intel
    "/opt/homebrew/opt/openjdk/bin/java"      # Homebrew "latest openjdk"
    "/usr/local/opt/openjdk/bin/java"
  )

  # First: check if the current java is already 21+
  if command -v java &>/dev/null; then
    local ver
    ver=$(java -version 2>&1 | awk -F'"' '/version/{print $2}' | cut -d. -f1)
    if [ "${ver:-0}" -ge 21 ] 2>/dev/null; then
      ok "System java is version $ver — no override needed"
      return 0
    fi
    warn "System java is version $ver (need 21+) — searching for a newer JDK..."
  fi

  # Try each candidate
  for candidate in "${candidates[@]}"; do
    if [ -x "$candidate" ]; then
      local ver
      ver=$("$candidate" -version 2>&1 | awk -F'"' '/version/{print $2}' | cut -d. -f1)
      if [ "${ver:-0}" -ge 21 ] 2>/dev/null; then
        export JAVA_HOME
        JAVA_HOME="$(dirname "$(dirname "$candidate")")"
        export PATH="$JAVA_HOME/bin:$PATH"
        ok "Using Java $ver from: $candidate"
        return 0
      fi
    fi
  done

  # Nothing worked
  err "Could not find Java 21+. Firebase emulator requires it."
  err ""
  err "Install options:"
  err "  brew install openjdk@21"
  err "  or download from https://adoptium.net"
  err ""
  err "After installing, re-run this script."
  exit 1
}

resolve_java21
java -version 2>&1 | head -1 | sed 's/^/     /'

# ─────────────────────────────────────────────────────────────────────────────
#  3. PREREQUISITE CHECKS
# ─────────────────────────────────────────────────────────────────────────────
section "Checking prerequisites"

require dart     "Install from https://dart.dev/get-dart"
require node     "Install from https://nodejs.org or via nvm"
require npm      "Comes with Node.js"
require firebase "Run: npm install -g firebase-tools"
require nc       "brew install netcat  (macOS)"

echo ""
log "All prerequisites satisfied."

# ─────────────────────────────────────────────────────────────────────────────
#  4. INSTALL NPM DEPENDENCIES
# ─────────────────────────────────────────────────────────────────────────────
section "Installing dependencies"

install_if_needed() {
  local dir=$1
  local label=$2
  if [ ! -d "$dir/node_modules" ]; then
    log "npm install → $label"
    npm install --prefix "$dir" --silent
    ok "$label dependencies installed"
  else
    ok "$label  node_modules ✓"
  fi
}

install_if_needed server "server"
if $START_CLIENT; then
  install_if_needed client "client"
fi

# Download Firebase emulator JARs on first run (cached at ~/.cache/firebase)
if [ ! -d "$HOME/.cache/firebase/emulators" ]; then
  log "Downloading Firebase emulator binaries (one-time download, ~60s)..."
  firebase setup:emulators:firestore --project "$FIREBASE_PROJECT" 2>&1 | tail -3
  ok "Firebase emulator binaries cached"
else
  ok "Firebase emulator binaries  cached ✓"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  5. PORT CONFLICT CHECK
# ─────────────────────────────────────────────────────────────────────────────
section "Checking ports"

check_port() {
  local port=$1
  local label=$2
  if nc -z localhost "$port" 2>/dev/null; then
    warn ":$port ($label) already in use — kill that process or it may conflict"
  else
    ok ":$port ($label) is free"
  fi
}

check_port $FIREBASE_UI_PORT "Firebase UI"
check_port $FIRESTORE_PORT   "Firestore emulator"
check_port $AUTH_PORT        "Auth emulator"
check_port $SERVER_PORT      "Express server"
if $START_CLIENT; then
  check_port $CLIENT_PORT "Client dev server"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  6. START FIREBASE EMULATOR SUITE
# ─────────────────────────────────────────────────────────────────────────────
section "Starting Firebase Emulator Suite"

EMULATOR_LOG="$SCRIPT_DIR/.emulator.log"

# JAVA_HOME is already exported from resolve_java21() above.
# firebase-tools spawns the emulator JARs in a subprocess — the exported
# JAVA_HOME ensures it picks up Java 21 even if the shell default is older.
firebase emulators:start \
  --project "$FIREBASE_PROJECT" \
  --only auth,firestore \
  > "$EMULATOR_LOG" 2>&1 &

EMULATOR_PID=$!
PIDS+=($EMULATOR_PID)
log "Firebase emulator PID: $EMULATOR_PID  (log → .emulator.log)"

wait_for_port $FIRESTORE_PORT "Firestore emulator"
wait_for_port $AUTH_PORT      "Auth emulator"

# ─────────────────────────────────────────────────────────────────────────────
#  7. START EXPRESS API SERVER
# ─────────────────────────────────────────────────────────────────────────────
section "Starting Express API server"

SERVER_LOG="$SCRIPT_DIR/.server.log"

FIRESTORE_EMULATOR_HOST=localhost:8090 npm run dev --prefix server > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!
PIDS+=($SERVER_PID)
log "Server PID: $SERVER_PID  (log → .server.log)"

wait_for_port $SERVER_PORT "Express server"

# ─────────────────────────────────────────────────────────────────────────────
#  8. START CLIENT DEV SERVER (optional)
# ─────────────────────────────────────────────────────────────────────────────
if $START_CLIENT; then
  section "Starting Phaser client (webpack-dev-server)"

  CLIENT_LOG="$SCRIPT_DIR/.client.log"

  npm run dev --prefix client > "$CLIENT_LOG" 2>&1 &
  CLIENT_PID=$!
  PIDS+=($CLIENT_PID)
  log "Client PID: $CLIENT_PID  (log → .client.log)"

  wait_for_port $CLIENT_PORT "Client dev server"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  9. RUN DART BATTLE ENGINE DEMO
# ─────────────────────────────────────────────────────────────────────────────
section "Running Dart battle engine demo"

cd battle_engine
dart run bin/main.dart 2>&1 | head -60
echo "  ... (truncated — run: cd battle_engine && dart run bin/main.dart)"
cd ..

ok "Battle engine demo complete"

# ─────────────────────────────────────────────────────────────────────────────
#  10. STATUS DASHBOARD
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  ✅  Likha Pet dev environment is running               ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Service                URL                              ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Firebase Emulator UI   ${CYAN}http://localhost:$FIREBASE_UI_PORT${NC}              ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Firestore emulator     ${CYAN}http://localhost:$FIRESTORE_PORT${NC}              ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Auth emulator          ${CYAN}http://localhost:$AUTH_PORT${NC}              ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Express API server     ${CYAN}http://localhost:$SERVER_PORT${NC}               ${BOLD}${GREEN}║${NC}"
if $START_CLIENT; then
echo -e "${BOLD}${GREEN}║${NC}  Phaser client          ${CYAN}http://localhost:$CLIENT_PORT${NC}               ${BOLD}${GREEN}║${NC}"
fi
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Logs:  .emulator.log · .server.log · .client.log       ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Engine: cd battle_engine && dart run bin/main.dart      ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}║${NC}  FIREBASE_PROJECT=${FIREBASE_PROJECT}              ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║${NC}  Press ${BOLD}Ctrl+C${NC} to stop all services                        ${BOLD}${GREEN}║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
#  11. OPEN BROWSER (macOS only)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
  open "http://localhost:$FIREBASE_UI_PORT" 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────────────────────
#  12. KEEP ALIVE — hold until Ctrl+C
# ─────────────────────────────────────────────────────────────────────────────
wait
