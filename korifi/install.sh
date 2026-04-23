export ROOT_NAMESPACE="cf"
export KORIFI_NAMESPACE="korifi"
export ADMIN_USERNAME="groot"
export BASE_DOMAIN="shivlab.com"
export GATEWAY_CLASS_NAME="contour"
export KORIFI_GATEWAY_NAMESPACE="korifi-gateway"


kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml
kubectl apply -f https://github.com/buildpacks-community/kpack/releases/download/v0.17.1/release-0.17.1.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcontour/contour/refs/heads/main/examples/render/contour-gateway-provisioner.yaml

kubectl apply -f - <<EOF
kind: GatewayClass
apiVersion: gateway.networking.k8s.io/v1beta1
metadata:
  name: $GATEWAY_CLASS_NAME
spec:
  controllerName: projectcontour.io/gateway-controller
EOF

kubectl apply -f https://github.com/servicebinding/runtime/releases/download/v1.0.0/servicebinding-runtime-v1.0.0.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $ROOT_NAMESPACE
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/enforce: restricted
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $KORIFI_NAMESPACE
  labels:
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/enforce: restricted
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $KORIFI_GATEWAY_NAMESPACE
EOF


helm install korifi https://github.com/cloudfoundry/korifi/releases/download/v0.18.0/korifi-0.18.0.tgz \
    --namespace="$KORIFI_NAMESPACE" \
    --set=generateIngressCertificates=true \
    --set=rootNamespace="$ROOT_NAMESPACE" \
    --set=adminUserName="$ADMIN_USERNAME" \
    --set=api.apiServer.url="api.$BASE_DOMAIN" \
    --set=defaultAppDomainName="apps.$BASE_DOMAIN" \
    --set=containerRepositoryPrefix=europe-docker.pkg.dev/my-project/korifi/ \
    --set=kpackImageBuilder.builderRepository=europe-docker.pkg.dev/my-project/korifi/kpack-builder \
    --set=networking.gatewayClass=$GATEWAY_CLASS_NAME \
    --set=networking.gatewayNamespace=$KORIFI_GATEWAY_NAMESPACE \
    --wait