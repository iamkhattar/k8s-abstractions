#!/usr/bin/env bash
set -euo pipefail

export ROOT_NAMESPACE="cf"
export KORIFI_NAMESPACE="korifi"
export ADMIN_USERNAME="system:admin"
export BASE_DOMAIN="shivlab.com"
export GATEWAY_CLASS_NAME="contour"
export KORIFI_GATEWAY_NAMESPACE="korifi-gateway"

export REGISTRY_NAMESPACE="docker-registry"
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

# ── 2. Resolve node IP + set registry coords ─────────────────────────────────
# Use node InternalIP + NodePort so kpack's HTTP client can reach the registry
# directly without relying on cluster DNS.
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
export REGISTRY_HOST="${NODE_IP}"
export REGISTRY_PORT="${REGISTRY_NODEPORT}"

echo "Registry will be ${REGISTRY_HOST}:${REGISTRY_PORT}"

# ── 3. Patch k3s containerd to trust the registry ────────────────────────────
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

# ── 4. cert-manager ──────────────────────────────────────────────────────────
# Apply twice — first pass installs CRDs, second pass creates CRs that depend
# on them. Idempotent on reruns.
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml || true
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml
kubectl rollout status deployment/cert-manager            -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook    -n cert-manager --timeout=120s

# ── 5. kpack ─────────────────────────────────────────────────────────────────
# Same double-apply pattern — ClusterLifecycle CR is in the same manifest as
# its CRD and loses the race on first apply.
kubectl apply -f https://github.com/buildpacks-community/kpack/releases/download/v0.17.1/release-0.17.1.yaml || true
kubectl apply -f https://github.com/buildpacks-community/kpack/releases/download/v0.17.1/release-0.17.1.yaml
kubectl rollout status deployment/kpack-controller -n kpack --timeout=120s
kubectl rollout status deployment/kpack-webhook    -n kpack --timeout=120s

# ── 6. Contour gateway provisioner ───────────────────────────────────────────
kubectl apply -f https://raw.githubusercontent.com/projectcontour/contour/refs/heads/main/examples/render/contour-gateway-provisioner.yaml || true
kubectl apply -f https://raw.githubusercontent.com/projectcontour/contour/refs/heads/main/examples/render/contour-gateway-provisioner.yaml
kubectl rollout status deployment/contour-gateway-provisioner -n projectcontour --timeout=120s

kubectl apply -f - <<EOF
kind: GatewayClass
apiVersion: gateway.networking.k8s.io/v1beta1
metadata:
  name: ${GATEWAY_CLASS_NAME}
spec:
  controllerName: projectcontour.io/gateway-controller
EOF

# ── 7. Service binding runtime ───────────────────────────────────────────────
kubectl apply -f https://github.com/servicebinding/runtime/releases/download/v1.0.0/servicebinding-runtime-v1.0.0.yaml || true
kubectl apply -f https://github.com/servicebinding/runtime/releases/download/v1.0.0/servicebinding-runtime-v1.0.0.yaml
kubectl rollout status deployment/servicebinding-controller-manager -n servicebinding-system --timeout=120s

# ── 8. Namespaces ─────────────────────────────────────────────────────────────
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${ROOT_NAMESPACE}
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${KORIFI_NAMESPACE}
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${KORIFI_GATEWAY_NAMESPACE}
EOF

# ── 9. Registry credentials secret ───────────────────────────────────────────
# Must exist in root namespace before Korifi installs — CFOrg reconciler
# propagates it into every org/space namespace. twuni has no auth but the
# secret is still required; dummy credentials satisfy the schema.
kubectl create secret docker-registry image-registry-credentials \
    --namespace="${ROOT_NAMESPACE}" \
    --docker-server="${REGISTRY_HOST}:${REGISTRY_PORT}" \
    --docker-username="unused" \
    --docker-password="unused" \
    --dry-run=client -o yaml | kubectl apply -f -

# ── 10. Korifi ────────────────────────────────────────────────────────────────
# adminUserName=system:admin matches the k3s default kubeconfig identity so
# no separate cert generation or role binding is needed — system:admin is
# already cluster-admin and Korifi will accept it as the CF admin user.
helm upgrade --install korifi \
    https://github.com/cloudfoundry/korifi/releases/download/v0.18.0/korifi-0.18.0.tgz \
    --namespace="${KORIFI_NAMESPACE}" \
    --set=generateIngressCertificates=true \
    --set=rootNamespace="${ROOT_NAMESPACE}" \
    --set=adminUserName="${ADMIN_USERNAME}" \
    --set=api.apiServer.url="api.${BASE_DOMAIN}" \
    --set=defaultAppDomainName="apps.${BASE_DOMAIN}" \
    --set=containerRepositoryPrefix="${REGISTRY_HOST}:${REGISTRY_PORT}/korifi/" \
    --set=kpackImageBuilder.builderRepository="${REGISTRY_HOST}:${REGISTRY_PORT}/korifi/kpack-builder" \
    --set=networking.gatewayClass="${GATEWAY_CLASS_NAME}" \
    --set=networking.gatewayNamespace="${KORIFI_GATEWAY_NAMESPACE}" \
    --wait

echo ""
echo "✓ Korifi install complete"
echo "  API endpoint : https://api.${BASE_DOMAIN}"
echo "  App domain   : https://apps.${BASE_DOMAIN}"
echo "  Registry     : ${REGISTRY_HOST}:${REGISTRY_PORT}"
echo ""
echo "  Next steps:"
echo "  cf api https://api.${BASE_DOMAIN} --skip-ssl-validation"
echo "  cf auth"
echo "  cf create-org <org>"