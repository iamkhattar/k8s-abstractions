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

# ── 2. Wait for Crossplane CRDs to be fully established ───────────────────────
# helm --wait ensures pods are ready, but the CRDs themselves (registered by
# those pods) can still be a few seconds behind. Gate on them explicitly before
# attempting to create any Crossplane resources.
echo ">>> Waiting for Crossplane CRDs to be established …"
for crd in \
  compositeresourcedefinitions.apiextensions.crossplane.io \
  compositions.apiextensions.crossplane.io \
  functions.pkg.crossplane.io \
  providers.pkg.crossplane.io \
  deploymentruntimeconfigs.pkg.crossplane.io; do
  kubectl wait --for=condition=Established "crd/${crd}" --timeout=120s
done

# ── 3. Install function-patch-and-transform ───────────────────────────────────
# Install the function BEFORE the Composition that references it; otherwise the
# Composition is accepted but immediately enters an error state.
echo ">>> Installing function-patch-and-transform"
kubectl apply -f - <<'EOF'
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.8.0
EOF

echo ">>> Waiting for function-patch-and-transform to become healthy …"
kubectl wait function/function-patch-and-transform \
  --for=condition=Healthy \
  --timeout=300s

# ── 4. Install the Kubernetes provider ────────────────────────────────────────
echo ">>> Installing provider-kubernetes ${PROVIDER_K8S_VERSION}"

# DeploymentRuntimeConfig must exist before the Provider references it.
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

echo ">>> Waiting for provider-kubernetes to become healthy …"
kubectl wait provider/provider-kubernetes \
  --for=condition=Healthy \
  --timeout=300s

# ── 5. Grant the provider SA cluster-admin (demo convenience only) ─────────────
# Tighten this for production.
# Crossplane names the SA after the provider per the DeploymentRuntimeConfig
# serviceAccountTemplate above. Wait for it to exist before binding.
echo ">>> Waiting for provider-kubernetes ServiceAccount to appear …"
until kubectl get sa provider-kubernetes -n "${NAMESPACE}" &>/dev/null; do
  sleep 2
done

kubectl create clusterrolebinding provider-kubernetes-admin \
  --clusterrole=cluster-admin \
  --serviceaccount="${NAMESPACE}:provider-kubernetes" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 6. ProviderConfig — talk to the local cluster ─────────────────────────────
kubectl apply -f - <<'EOF'
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: in-cluster
spec:
  credentials:
    source: InjectedIdentity
EOF

# ── 7. CompositeResourceDefinition (XRD) ──────────────────────────────────────
# Declares the developer-facing "Application" CRD; equivalent to kro's
# ResourceGraphDefinition.
echo ">>> Applying XRD (XApplication / Application)"
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

echo ">>> Waiting for XRD to be established …"
kubectl wait xrd/xapplications.demo.shivlab.com \
  --for=condition=Established \
  --timeout=120s

echo ">>> Waiting for XRD claim CRD (applications.demo.shivlab.com) to be established …"
kubectl wait --for=condition=Established \
  crd/applications.demo.shivlab.com \
  --timeout=120s

# ── 8. Composition ─────────────────────────────────────────────────────────────
# Wires XApplication → Deployment + Service + Ingress via provider-kubernetes
# Objects. Ingress is always created; gate ingress.enabled at the claim level
# or switch to function-go-templating for conditional resource rendering.
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

          # ── Deployment ──────────────────────────────────────────────────────
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

          # ── Service ─────────────────────────────────────────────────────────
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
                      type: Format
                      fmt: "%s-svc"
              - type: FromCompositeFieldPath
                fromFieldPath: spec.name
                toFieldPath: spec.forProvider.manifest.spec.selector.app

          # ── Ingress ─────────────────────────────────────────────────────────
          # Note: always created. To make this conditional on ingress.enabled,
          # replace this step with function-go-templating.
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
                      type: Format
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
                      type: Format
                      fmt: "%s-svc"
EOF

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "✔  Crossplane bootstrap complete."
echo ""
echo "    XRD:         kubectl get xrd xapplications.demo.shivlab.com"
echo "    Composition: kubectl get composition application-composition"
echo "    Apply demo:  kubectl apply -f instance.yaml"
echo ""