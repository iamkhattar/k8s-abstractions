Output kro-demo.mp4

Require echo
Require kubectl

Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950


# ── Instantiate the Application ───────────────────────────────────────────────

Type "echo 'KRO Demo'"
Sleep 500ms
Enter 1
Sleep 2s

Type "echo 'Creating Application instance'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl apply -f instance.yaml"
Sleep 500ms
Enter 1
Sleep 4s

Type "kubectl get applications"
Sleep 500ms
Enter 1
Sleep 4s

# ── Inspect reconciled resources ──────────────────────────────────────────────

Type "echo 'Inspecting reconciled resources'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

# ── Show kro reconciliation in action ────────────────────────────────────────

Type "echo 'Deleting service — watch kro reconcile it back'"
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

# ── Scale up via instance update ─────────────────────────────────────────────

Type "echo 'Scaling replicas to 3 via instance patch'"
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

# ── Curl the app through Traefik ──────────────────────────────────────────────

Type "echo 'Hitting the app through Traefik ingress'"
Sleep 500ms
Enter 1
Sleep 1s

Type "curl -s http://nginx.shivlab.com"
Sleep 500ms
Enter 1
Sleep 4s

# ── Clean up ──────────────────────────────────────────────────────────────────

Type "echo 'Cleaning up'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl delete application my-app-instance"
Sleep 500ms
Enter 1
Sleep 4s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

Type "echo 'Done — all child resources removed by kro'"
Sleep 500ms
Enter 1
Sleep 2s