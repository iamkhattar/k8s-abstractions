#!/usr/bin/env bash
set -euo pipefail

export ROOT_NAMESPACE="cf"
export KORIFI_NAMESPACE="korifi"
export ADMIN_USERNAME="groot"
export BASE_DOMAIN="shivlab.com"
export GATEWAY_CLASS_NAME="contour"
export KORIFI_GATEWAY_NAMESPACE="korifi-gateway"

export REGISTRY_NAMESPACE="docker-registry"
export REGISTRY_HOST="localregistry-docker-registry.${REGISTRY_NAMESPACE}.svc.cluster.local"
export REGISTRY_PORT="5000"
export REGISTRY_NODEPORT="30050"

# ── 1. In-cluster registry (twuni) ───────────────────────────────────────────
helm repo add twuni https://twuni.github.io/docker-registry.helm
helm repo update

kubectl create namespace "$REGISTRY_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install docker-registry twuni/docker-registry \
    --namespace "$REGISTRY_NAMESPACE" \
    --set service.type=NodePort \
    --set service.nodePort="$REGISTRY_NODEPORT" \
    --set persistence.enabled=true \
    --set persistence.size=10Gi \
    --wait

# ── 2. Patch k3s containerd ───────────────────────────────────────────────────
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml > /dev/null <<EOF
mirrors:
  "${REGISTRY_HOST}:${REGISTRY_PORT}":
    endpoint:
      - "http://127.0.0.1:${REGISTRY_NODEPORT}"
configs:
  "127.0.0.1:${REGISTRY_NODEPORT}":
    tls:
      insecure_skip_verify: true
EOF

echo "Restarting k3s to pick up registry config..."
sudo systemctl restart k3s
kubectl wait node --all --for=condition=Ready --timeout=120s

# ── 3. cert-manager ──────────────────────────────────────────────────────────
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

# ── 4. kpack ─────────────────────────────────────────────────────────────────
kubectl apply -f https://github.com/buildpacks-community/kpack/releases/download/v0.17.1/release-0.17.1.yaml
kubectl rollout status deployment/kpack-controller -n kpack --timeout=120s
kubectl rollout status deployment/kpack-webhook -n kpack --timeout=120s

# ── 5. Contour gateway provisioner ───────────────────────────────────────────
kubectl apply -f https://raw.githubusercontent.com/projectcontour/contour/refs/heads/main/examples/render/contour-gateway-provisioner.yaml
kubectl rollout status deployment/contour-gateway-provisioner -n projectcontour --timeout=120s

kubectl apply -f - <<EOF
kind: GatewayClass
apiVersion: gateway.networking.k8s.io/v1beta1
metadata:
  name: $GATEWAY_CLASS_NAME
spec:
  controllerName: projectcontour.io/gateway-controller
EOF

# ── 6. Service binding runtime ───────────────────────────────────────────────
kubectl apply -f https://github.com/servicebinding/runtime/releases/download/v1.0.0/servicebinding-runtime-v1.0.0.yaml
kubectl rollout status deployment/servicebinding-controller-manager -n servicebinding-system --timeout=120s

# ── 7. Namespaces ─────────────────────────────────────────────────────────────
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $ROOT_NAMESPACE
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: $KORIFI_NAMESPACE
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: $KORIFI_GATEWAY_NAMESPACE
EOF

# ── 8. Registry credentials secret ───────────────────────────────────────────
# Korifi's CFOrg controller propagates this secret into every org/space namespace.
# twuni has no auth configured, but the secret must exist — use dummy values.
kubectl create secret docker-registry image-registry-credentials \
    --namespace="$ROOT_NAMESPACE" \
    --docker-server="${REGISTRY_HOST}:${REGISTRY_PORT}" \
    --docker-username="unused" \
    --docker-password="unused" \
    --dry-run=client -o yaml | kubectl apply -f -

# ── 9. Korifi ─────────────────────────────────────────────────────────────────
helm install korifi https://github.com/cloudfoundry/korifi/releases/download/v0.18.0/korifi-0.18.0.tgz \
    --namespace="$KORIFI_NAMESPACE" \
    --set=generateIngressCertificates=true \
    --set=rootNamespace="$ROOT_NAMESPACE" \
    --set=adminUserName="$ADMIN_USERNAME" \
    --set=api.apiServer.url="api.$BASE_DOMAIN" \
    --set=defaultAppDomainName="apps.$BASE_DOMAIN" \
    --set=containerRepositoryPrefix="${REGISTRY_HOST}:${REGISTRY_PORT}/korifi/" \
    --set=kpackImageBuilder.builderRepository="${REGISTRY_HOST}:${REGISTRY_PORT}/korifi/kpack-builder" \
    --set=networking.gatewayClass=$GATEWAY_CLASS_NAME \
    --set=networking.gatewayNamespace=$KORIFI_GATEWAY_NAMESPACE \
    --wait