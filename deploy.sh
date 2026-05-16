#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Paksi Game — Production Deployment Script
#
#  Deploys:
#    1. Firestore rules + indexes       → Firebase (paksi-game-beta)
#    2. Express + WebSocket server      → Cloud Run  (paksi-game-beta)
#    3. Flutter web app                 → Firebase Hosting (paksi-game-beta)
#
#  Prerequisites:
#    firebase-tools  npm install -g firebase-tools && firebase login
#    gcloud CLI      https://cloud.google.com/sdk/docs/install && gcloud auth login
#    flutter         https://flutter.dev/docs/get-started/install
#    docker          https://docs.docker.com/get-docker/
#
#  First-time setup:
#    1. Run: gcloud config set project paksi-game-beta
#    2. Enable APIs:
#         gcloud services enable run.googleapis.com \
#           cloudbuild.googleapis.com \
#           secretmanager.googleapis.com \
#           firestore.googleapis.com
#    3. Create JWT secret:
#         echo -n "your-strong-secret-here" | \
#           gcloud secrets create JWT_SECRET --data-file=-
#    4. Grant Cloud Run access to Secret Manager:
#         PROJECT_NUM=$(gcloud projects describe paksi-game-beta --format='value(projectNumber)')
#         gcloud secrets add-iam-policy-binding JWT_SECRET \
#           --member="serviceAccount:${PROJECT_NUM}-compute@developer.gserviceaccount.com" \
#           --role="roles/secretmanager.secretAccessor"
#
#  Usage:
#    ./deploy.sh                — deploy everything
#    ./deploy.sh --firestore    — Firestore rules + indexes only
#    ./deploy.sh --server       — Cloud Run server only
#    ./deploy.sh --web          — Flutter web + Hosting only
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Ensure gcloud is in PATH ──────────────────────────────────────────────────
GCLOUD_SDK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/google-cloud-sdk"
if [ -d "$GCLOUD_SDK_DIR/bin" ]; then
  export PATH="$GCLOUD_SDK_DIR/bin:$PATH"
fi

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT_ID="paksi-game-beta"
REGION="asia-southeast1"           # Change if needed (e.g. us-central1)
SERVICE_NAME="paksi-server"
IMAGE="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RED='\033[0;31m'; NC='\033[0m'

log()  { echo -e "${BOLD}[deploy]${NC} $*"; }
ok()   { echo -e "${GREEN}  ✔${NC}  $*"; }
err()  { echo -e "${RED}  ✘${NC}  $*"; exit 1; }

# ── Parse flags ───────────────────────────────────────────────────────────────
DEPLOY_FIRESTORE=true
DEPLOY_SERVER=true
DEPLOY_WEB=true

if [[ $# -gt 0 ]]; then
  DEPLOY_FIRESTORE=false; DEPLOY_SERVER=false; DEPLOY_WEB=false
  for arg in "$@"; do
    case $arg in
      --firestore) DEPLOY_FIRESTORE=true ;;
      --server)    DEPLOY_SERVER=true ;;
      --web)       DEPLOY_WEB=true ;;
      *) err "Unknown flag: $arg" ;;
    esac
  done
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─────────────────────────────────────────────────────────────────────────────
#  1. FIRESTORE RULES + INDEXES
# ─────────────────────────────────────────────────────────────────────────────
if $DEPLOY_FIRESTORE; then
  echo ""
  echo -e "${CYAN}${BOLD}── Deploying Firestore rules + indexes ──${NC}"
  firebase deploy --only firestore --project "$PROJECT_ID"
  ok "Firestore rules and indexes deployed"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  2. SERVER → CLOUD RUN
# ─────────────────────────────────────────────────────────────────────────────
if $DEPLOY_SERVER; then
  echo ""
  echo -e "${CYAN}${BOLD}── Building + deploying server to Cloud Run ──${NC}"

  log "Building Docker image: $IMAGE"
  docker build --platform linux/amd64 -t "$IMAGE" server/
  docker push "$IMAGE"
  ok "Image pushed to Container Registry"

  # Resolve the JWT_SECRET from Secret Manager at deploy time.
  log "Deploying to Cloud Run ($REGION)..."
  gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE" \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-env-vars "FIREBASE_PROJECT_ID=${PROJECT_ID}" \
    --set-secrets "JWT_SECRET=JWT_SECRET:latest" \
    --min-instances 1 \
    --max-instances 10 \
    --memory 512Mi \
    --cpu 1 \
    --timeout 3600 \
    --no-use-http2 \
    --project "$PROJECT_ID"

  SERVER_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --format 'value(status.url)')
  ok "Server deployed → $SERVER_URL"
  echo ""
  log "Server URL for Flutter build: $SERVER_URL"
  # Export so the web build step can use it if run together
  export PAKSI_SERVER_URL="$SERVER_URL"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  3. FLUTTER WEB → FIREBASE HOSTING
# ─────────────────────────────────────────────────────────────────────────────
if $DEPLOY_WEB; then
  echo ""
  echo -e "${CYAN}${BOLD}── Building Flutter web app ──${NC}"

  # Use server URL from env (set by step 2, or override manually).
  # For WebSocket, derive wss:// from https:// server URL.
  if [[ -z "${PAKSI_SERVER_URL:-}" ]]; then
    log "PAKSI_SERVER_URL not set — reading from Cloud Run..."
    PAKSI_SERVER_URL=$(gcloud run services describe "$SERVICE_NAME" \
      --region "$REGION" \
      --project "$PROJECT_ID" \
      --format 'value(status.url)' 2>/dev/null || echo "")
    if [[ -z "$PAKSI_SERVER_URL" ]]; then
      err "Could not determine server URL. Run --server first, or set PAKSI_SERVER_URL env var."
    fi
  fi

  # Convert https://... → wss://...
  WS_URL="${PAKSI_SERVER_URL/https:\/\//wss://}/pvp"
  log "SERVER_URL = $PAKSI_SERVER_URL"
  log "WS_URL     = $WS_URL"

  cd app
  flutter build web \
    --release \
    --dart-define="SERVER_URL=${PAKSI_SERVER_URL}" \
    --dart-define="WS_URL=${WS_URL}"
  cd ..
  ok "Flutter web build complete"

  log "Deploying to Firebase Hosting..."
  firebase deploy --only hosting --project "$PROJECT_ID"
  ok "Flutter web deployed to Firebase Hosting"

  HOSTING_URL="https://${PROJECT_ID}.web.app"
  ok "Live at → $HOSTING_URL"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  ✅  Deployment complete                                ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
if $DEPLOY_FIRESTORE; then
echo -e "${BOLD}${GREEN}║${NC}  Firestore   rules + indexes updated                     ${BOLD}${GREEN}║${NC}"
fi
if $DEPLOY_SERVER; then
echo -e "${BOLD}${GREEN}║${NC}  Server      ${PAKSI_SERVER_URL:-check Cloud Run console}   ${BOLD}${GREEN}║${NC}"
fi
if $DEPLOY_WEB; then
echo -e "${BOLD}${GREEN}║${NC}  Web app     https://${PROJECT_ID}.web.app              ${BOLD}${GREEN}║${NC}"
fi
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
