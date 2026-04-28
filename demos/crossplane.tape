Output output.mp4

Require echo
Require kubectl

Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950

# ── Show the XRD and Composition are in place ─────────────────────────────────

Type "echo 'Crossplane Demo'"
Sleep 500ms
Enter 1
Sleep 2s

Type "echo 'XRD and Composition installed by bootstrap script'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl get xrd xapplications.demo.shivlab.com"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl get composition application-composition"
Sleep 500ms
Enter 1
Sleep 3s

# ── Instantiate via a developer claim ────────────────────────────────────────

Type "echo 'Developer creates an Application claim — nothing else needed'"
Sleep 500ms
Enter 1
Sleep 1s

Type "cat instance.yaml"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl apply -f instance.yaml"
Sleep 500ms
Enter 1
Sleep 4s

Type "kubectl get applications"
Sleep 500ms
Enter 1
Sleep 4s

# ── Watch Crossplane compose the child resources ──────────────────────────────

Type "echo 'Crossplane composing child resources via provider-kubernetes'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl get managed"
Sleep 500ms
Enter 1
Sleep 4s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

# ── Show composite status ─────────────────────────────────────────────────────

Type "echo 'Inspecting composite status'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl describe application my-app-instance | grep -A 20 'Status:'"
Sleep 500ms
Enter 1
Sleep 4s

# ── Reconciliation in action ──────────────────────────────────────────────────

Type "echo 'Deleting service — watch Crossplane reconcile it back'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl delete service my-app-svc"
Sleep 500ms
Enter 1
Sleep 2s

Type "kubectl get service my-app-svc -w"
Sleep 500ms
Enter 1
Sleep 6s
Ctrl+C
Sleep 1s

# ── Scale up via claim patch ──────────────────────────────────────────────────

Type "echo 'Scaling replicas to 3 — developer only touches the claim'"
Sleep 500ms
Enter 1
Sleep 1s

Type "echo 'spec:' > patch.yaml && echo '  replicas: 3' >> patch.yaml"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl patch application my-app-instance --type=merge --patch-file patch.yaml"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl get deployment my-app -w"
Sleep 500ms
Enter 1
Sleep 6s
Ctrl+C
Sleep 1s

# ── Curl through Traefik ──────────────────────────────────────────────────────

Type "echo 'Hitting the app through Traefik ingress'"
Sleep 500ms
Enter 1
Sleep 1s

Type "curl -s http://nginx.shivlab.com"
Sleep 500ms
Enter 1
Sleep 4s

# ── Show the composition graph ────────────────────────────────────────────────

Type "echo 'Composition graph — what Crossplane is managing'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl get composite my-app-instance -o jsonpath='{.spec.resourceRefs}' | jq ."
Sleep 500ms
Enter 1
Sleep 4s

# ── Clean up ──────────────────────────────────────────────────────────────────

Type "echo 'Deleting the claim — all composed resources follow'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl delete application my-app-instance"
Sleep 500ms
Enter 1
Sleep 5s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

Type "echo 'Done — Crossplane cascaded deletion to all child resources'"
Sleep 500ms
Enter 1
Sleep 2s
