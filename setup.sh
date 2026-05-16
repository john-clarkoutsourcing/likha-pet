#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Likha Pet — Dev Setup Script
#  Run once after cloning the repo.
# ─────────────────────────────────────────────────────────────────────────────
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✔${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }
err()  { echo -e "${RED}  ✘${NC}  $*"; exit 1; }

echo ""
echo -e "${BOLD}  Likha Pet — Setup${NC}"
echo ""

# ── 1. Flutter ────────────────────────────────────────────────────────────────
if ! command -v flutter &>/dev/null; then
  warn "Flutter not found."
  echo "     Install it from: https://docs.flutter.dev/get-started/install"
  echo "     Then re-run this script."
  exit 1
fi
ok "Flutter $(flutter --version 2>/dev/null | head -1 | awk '{print $2}')"

# ── 2. Docker ─────────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  warn "Docker not found."
  echo "     Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
  echo "     Then re-run this script."
  exit 1
fi
ok "Docker $(docker --version | awk '{print $3}' | tr -d ',')"

# ── 3. Flutter dependencies ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Installing Flutter packages...${NC}"
cd app && flutter pub get && cd ..
ok "Flutter packages installed"

# ── 4. Build Docker images ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Building Docker images (first run takes ~3 minutes)...${NC}"
docker compose build
ok "Docker images built"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  Setup complete! To start developing:${NC}"
echo ""
echo -e "  ${BOLD}If you have Flutter installed:${NC}"
echo -e "    1. docker compose up -d"
echo -e "    2. cd app && flutter run -d chrome"
echo ""
echo -e "  ${BOLD}If you don't have Flutter installed (Docker only):${NC}"
echo -e "    docker compose --profile full up -d"
echo -e "    Then open: http://localhost:8080"
echo -e "    (first build takes ~5 min)"
echo ""
echo -e "  ${BOLD}Just want to play? No setup needed:${NC}"
echo -e "    https://paksi-game-beta.web.app"
echo ""
