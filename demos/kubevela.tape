Output output.mp4

Require echo
Require kubectl
Require helm
Require vela

Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950

# -- Install CLI + core
Type "echo '==> Installing KubeVela CLI'"
Sleep 500ms
Enter 1
Sleep 1s

Type "curl -fsSL https://kubevela.io/script/install.sh | bash"
Sleep 500ms
Enter 1
Sleep 8s

Type "vela version"
Sleep 500ms
Enter 1
Sleep 2s

# -- Helm install
Type "helm repo add kubevela https://kubevela.github.io/charts && helm repo update"
Sleep 500ms
Enter 1
Sleep 4s

Type "helm install --create-namespace -n vela-system kubevela kubevela/vela-core --wait"
Sleep 500ms
Enter 1
Sleep 20s

# -- Verify core is up
Type "kubectl get pods -n vela-system"
Sleep 500ms
Enter 1
Sleep 4s

# -- VelaUX addon
Type "vela addon enable velaux"
Sleep 500ms
Enter 1
Sleep 10s

# -- Verify addon pods
Type "kubectl get pods -n vela-system"
Sleep 500ms
Enter 1
Sleep 4s

# -- Prep environment
Type "vela env init prod --namespace prod"
Sleep 500ms
Enter 1
Sleep 2s

# -- Deploy first app (two-env workflow with manual approval gate)
Type "vela up -f https://kubevela.io/example/applications/first-app.yaml"
Sleep 500ms
Enter 1
Sleep 6s

# -- Check status (will be workflowSuspending - waiting for approval at the gate)
Type "vela status first-vela-app"
Sleep 500ms
Enter 1
Sleep 4s

# -- Port-forward to hit the app in default ns
Type "vela port-forward first-vela-app 8000:8000 &"
Sleep 500ms
Enter 1
Sleep 3s

Type "curl http://localhost:8000"
Sleep 500ms
Enter 1
Sleep 4s

# -- Resume workflow to promote to prod (2 replicas via deploy-ha override)
Type "vela workflow resume first-vela-app"
Sleep 500ms
Enter 1
Sleep 4s

# -- Final status - should show running across default + prod
Type "vela status first-vela-app"
Sleep 500ms
Enter 1
Sleep 4s

Type "kubectl get pods -n prod"
Sleep 500ms
Enter 1
Sleep 4s

# -- Cleanup
Type "vela delete first-vela-app"
Sleep 500ms
Enter 1
Sleep 4s