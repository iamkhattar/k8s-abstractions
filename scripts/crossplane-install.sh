#!/usr/bin/env bash
set -euo pipefail

# ── Crossplane ────────────────────────────────────────────────────────────────

echo "▶ Installing Crossplane"
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane

echo "▶ Waiting for Crossplane to be ready"
kubectl rollout status deployment/crossplane -n crossplane-system --timeout=120s
kubectl rollout status deployment/crossplane-rbac-manager -n crossplane-system --timeout=120s

# ── provider-kubernetes ───────────────────────────────────────────────────────

echo "▶ Installing provider-kubernetes"
kubectl apply -f - <<'EOF'
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.1
EOF

echo "▶ Waiting for provider-kubernetes to be healthy"
kubectl wait provider/provider-kubernetes \
  --for=condition=Healthy \
  --timeout=180s

# ── RBAC for provider-kubernetes ─────────────────────────────────────────────

echo "▶ Configuring in-cluster RBAC for provider-kubernetes"
kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-kubernetes-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: provider-kubernetes
    namespace: crossplane-system
EOF

# ── ProviderConfig ────────────────────────────────────────────────────────────

echo "▶ Applying ProviderConfig"
kubectl apply -f - <<'EOF'
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

# ── XRD ───────────────────────────────────────────────────────────────────────

echo "▶ Applying CompositeResourceDefinition"
kubectl apply -f - <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xappinstances.shivlab.com
spec:
  group: shivlab.com
  names:
    kind: XAppInstance
    plural: xappinstances
  claimNames:
    kind: AppClaim
    plural: appclaims
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
              required: [name, image]
              properties:
                name:
                  type: string
                image:
                  type: string
                  default: nginx
                replicas:
                  type: integer
                  default: 2
                ingressEnabled:
                  type: boolean
                  default: false
                host:
                  type: string
                  default: app.shivlab.com
            status:
              type: object
              properties:
                url:
                  type: string
EOF

echo "▶ Waiting for XRD to become established"
kubectl wait xrd/xappinstances.shivlab.com \
  --for=condition=Established \
  --timeout=60s

# ── Composition ───────────────────────────────────────────────────────────────

echo "▶ Applying Composition"
kubectl apply -f - <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: appinstance-composition
  labels:
    shivlab.com/provider: kubernetes
spec:
  compositeTypeRef:
    apiVersion: shivlab.com/v1alpha1
    kind: XAppInstance

  resources:
    - name: deployment
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                namespace: default
              spec:
                selector:
                  matchLabels:
                    app: placeholder
                template:
                  metadata:
                    labels:
                      app: placeholder
                  spec:
                    containers:
                      - name: app
                        image: nginx
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

    - name: service
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Service
              metadata:
                namespace: default
              spec:
                ports:
                  - port: 80
                    targetPort: 80
                selector:
                  app: placeholder
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

    - name: ingress
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
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
                  - host: placeholder
                    http:
                      paths:
                        - path: /
                          pathType: Prefix
                          backend:
                            service:
                              name: placeholder
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
          fromFieldPath: spec.host
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

echo "✓ Crossplane fully configured — XRD and Composition ready"
echo "  Apply a Claim to deploy an app:"
echo "    kubectl apply -f claim.yaml"