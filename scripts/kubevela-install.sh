#!/usr/bin/env bash
set -euo pipefail

KUBEVELA_VERSION="1.10.8"
VELA_NAMESPACE="vela-system"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
info "Checking prerequisites..."
for cmd in helm kubectl; do
  command -v "$cmd" &>/dev/null || error "'$cmd' not found on PATH"
done
info "Prerequisites OK"

# ── Helm repo ─────────────────────────────────────────────────────────────────
info "Adding KubeVela helm repo..."
helm repo add kubevela https://kubevela.github.io/charts
helm repo update

# ── Install vela-core ─────────────────────────────────────────────────────────
info "Installing KubeVela v${KUBEVELA_VERSION} into namespace '${VELA_NAMESPACE}'..."
helm upgrade --install kubevela kubevela/vela-core \
  --namespace "${VELA_NAMESPACE}" \
  --create-namespace \
  --version "${KUBEVELA_VERSION}" \
  --wait \
  --timeout 5m

info "vela-core installed"

# ── Install vela CLI ──────────────────────────────────────────────────────────
if command -v vela &>/dev/null; then
  warn "vela CLI already on PATH ($(vela version --client 2>/dev/null | head -1)), skipping install"
else
  info "Installing vela CLI v${KUBEVELA_VERSION}..."
  curl -fsSL https://kubevela.io/script/install.sh | bash -s "${KUBEVELA_VERSION}"
fi

# ── Verify ────────────────────────────────────────────────────────────────────
info "Waiting for vela-core pods to be ready..."
kubectl rollout status deployment/kubevela-vela-core \
  --namespace "${VELA_NAMESPACE}" \
  --timeout 3m

info "Installed pods:"
kubectl get pods --namespace "${VELA_NAMESPACE}"

echo ""
info "KubeVela v${KUBEVELA_VERSION} ready."
info "Next: vela env init prod --namespace prod && vela up -f app.yaml"