#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# install-crossplane.sh
# Bootstraps Crossplane with the Kubernetes provider and a composite resource
# (XRD + Composition) equivalent to the kro ResourceGraphDefinition demo.
#
# Prerequisites: helm, kubectl, a running cluster (k3s/kind/etc.)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

CROSSPLANE_VERSION="1.17.1"
PROVIDER_K8S_VERSION="0.15.0"
NAMESPACE="crossplane-system"

# ── 1. Install Crossplane via Helm ────────────────────────────────────────────
echo ">>> Installing Crossplane ${CROSSPLANE_VERSION}"
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update crossplane-stable

helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --version "${CROSSPLANE_VERSION}" \
  --set args='{"--enable-usages"}' \
  --wait

echo ">>> Crossplane pods:"
kubectl get pods -n "${NAMESPACE}"

# ── 2. Install the Kubernetes provider ────────────────────────────────────────
echo ">>> Installing provider-kubernetes ${PROVIDER_K8S_VERSION}"
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v${PROVIDER_K8S_VERSION}
  runtimeConfigRef:
    name: provider-kubernetes-config
EOF

# Give the provider a runtime config so its SA has cluster-admin for the demo.
# Tighten this for production.
kubectl apply -f - <<'EOF'
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-kubernetes-config
spec:
  serviceAccountTemplate:
    metadata:
      name: provider-kubernetes
EOF

echo ">>> Waiting for provider-kubernetes to become healthy …"
kubectl wait provider/provider-kubernetes \
  --for=condition=Healthy \
  --timeout=300s

# Grant the provider's SA cluster-admin (demo convenience only)
PROVIDER_SA=$(kubectl get sa -n "${NAMESPACE}" \
  -o jsonpath='{.items[?(@.metadata.annotations.pkg\.crossplane\.io/revision)].metadata.name}' \
  | tr ' ' '\n' | grep provider-kubernetes | head -1)

kubectl create clusterrolebinding provider-kubernetes-admin \
  --clusterrole=cluster-admin \
  --serviceaccount="${NAMESPACE}:${PROVIDER_SA}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 3. ProviderConfig — talk to the local cluster ─────────────────────────────
kubectl apply -f - <<'EOF'
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: in-cluster
spec:
  credentials:
    source: InjectedIdentity
EOF

# ── 4. CompositeResourceDefinition (XRD) ─────────────────────────────────────
# Equivalent to kro's ResourceGraphDefinition: declares the "Application" CRD
# that developers interact with.
echo ">>> Applying XRD (Application)"
kubectl apply -f - <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xapplications.demo.shivlab.com
spec:
  group: demo.shivlab.com
  names:
    kind: XApplication
    plural: xapplications
  claimNames:
    kind: Application
    plural: applications
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required:
                - name
              properties:
                name:
                  type: string
                image:
                  type: string
                  default: nginx
                replicas:
                  type: integer
                  default: 2
                ingress:
                  type: object
                  properties:
                    enabled:
                      type: boolean
                      default: false
                    host:
                      type: string
                      default: app.local
            status:
              type: object
              properties:
                availableReplicas:
                  type: integer
EOF

# ── 5. Composition ────────────────────────────────────────────────────────────
# Wires the XApplication schema to real Kubernetes resources via
# provider-kubernetes Objects (Deployment + Service + Ingress).
echo ">>> Applying Composition"
kubectl apply -f - <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: application-composition
  labels:
    crossplane.io/xrd: xapplications.demo.shivlab.com
spec:
  compositeTypeRef:
    apiVersion: demo.shivlab.com/v1alpha1
    kind: XApplication

  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:

          # ── Deployment ────────────────────────────────────────────────────
          - name: deployment
            base:
              apiVersion: kubernetes.crossplane.io/v1alpha2
              kind: Object
              spec:
                providerConfigRef:
                  name: in-cluster
                forProvider:
                  manifest:
                    apiVersion: apps/v1
                    kind: Deployment
                    metadata:
                      namespace: default
                    spec:
                      selector:
                        matchLabels: {}
                      template:
                        metadata:
                          labels: {}
                        spec:
                          containers:
                            - name: app
                              ports:
                                - containerPort: 80
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.spec.selector.matchLabels.app
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.spec.template.metadata.labels.app
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.image
                toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].image
              - type: FromCompositeFieldPath
                fromFieldPath: spec.replicas
                toFieldPath: spec.forProvider.manifest.spec.replicas

          # ── Service ───────────────────────────────────────────────────────
          - name: service
            base:
              apiVersion: kubernetes.crossplane.io/v1alpha2
              kind: Object
              spec:
                providerConfigRef:
                  name: in-cluster
                forProvider:
                  manifest:
                    apiVersion: v1
                    kind: Service
                    metadata:
                      namespace: default
                    spec:
                      ports:
                        - protocol: TCP
                          port: 80
                          targetPort: 80
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.metadata.name
                transforms:
                  - type: string
                    string:
                      fmt: "%s-svc"
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.spec.selector.app

          # ── Ingress (always created; ingress.enabled controls annotation) ─
          # Crossplane compositions can't conditionally omit resources without
          # function-go-templating; here we gate at the claim level or use a
          # separate composition selected by a label.
          - name: ingress
            base:
              apiVersion: kubernetes.crossplane.io/v1alpha2
              kind: Object
              spec:
                providerConfigRef:
                  name: in-cluster
                forProvider:
                  manifest:
                    apiVersion: networking.k8s.io/v1
                    kind: Ingress
                    metadata:
                      namespace: default
                      annotations:
                        kubernetes.io/ingress.class: traefik
                    spec:
                      rules:
                        - http:
                            paths:
                              - path: "/"
                                pathType: Prefix
                                backend:
                                  service:
                                    port:
                                      number: 80
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.metadata.name
                transforms:
                  - type: string
                    string:
                      fmt: "%s-ingress"
              - type: FromCompositeFieldPath
                fromFieldPath: spec.ingress.host
                toFieldPath: spec.forProvider.manifest.spec.rules[0].host
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.spec.rules[0].http.paths[0].backend.service.name
                transforms:
                  - type: string
                    string:
                      fmt: "%s-svc"
EOF

# ── 6. Install function-patch-and-transform ───────────────────────────────────
echo ">>> Installing function-patch-and-transform"
kubectl apply -f - <<'EOF'
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.8.0
EOF

kubectl wait function/function-patch-and-transform \
  --for=condition=Healthy \
  --timeout=300s

echo ""
echo "✔  Crossplane bootstrap complete."
echo ""
echo "    XRD:         kubectl get xrd xapplications.demo.shivlab.com"
echo "    Composition: kubectl get composition application-composition"
echo "    Apply demo:  kubectl apply -f instance.yaml"
echo ""