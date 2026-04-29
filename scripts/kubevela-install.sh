#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing KubeVela CLI"
curl -fsSL https://kubevela.io/script/install.sh | bash

echo "==> Adding KubeVela Helm repo"
helm repo add kubevela https://kubevela.github.io/charts
helm repo update

echo "==> Installing KubeVela core into vela-system namespace"
helm install \
  --create-namespace \
  -n vela-system \
  kubevela kubevela/vela-core \
  --wait

echo "==> Waiting for KubeVela pods to be ready"
kubectl wait --for=condition=Ready pods \
  -l app.kubernetes.io/name=vela-core \
  -n vela-system \
  --timeout=300s

echo "==> Enabling VelaUX addon (dashboard)"
vela addon enable velaux

echo "==> Creating prod namespace for first-app workflow"
vela env init prod --namespace prod

echo ""
echo "KubeVela is ready."
echo "  Dashboard:  vela port-forward addon-velaux -n vela-system 8080:80"
echo "  Default creds: admin / VelaUX12345"