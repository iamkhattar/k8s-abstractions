Output output.mp4

Require echo
Require pulumi
Require kubectl

Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950

Env PULUMI_CONFIG_PASSPHRASE ""

# ── Login to local state ──────────────────────────────────────────────────────

Type "echo 'Pulumi k3s Demo'"
Sleep 500ms
Enter 1
Sleep 2s

Type "pulumi login --local"
Sleep 500ms
Enter 1
Wait@15s

# ── Stack init & config ───────────────────────────────────────────────────────

Type "echo 'Initialising stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "pulumi stack init dev"
Sleep 500ms
Enter 1
Wait@15s

Type "pulumi config set k3s-app:name my-app"
Sleep 500ms
Enter 1
Wait@5s

Type "pulumi config set k3s-app:image nginx"
Sleep 500ms
Enter 1
Wait@5s

Type "pulumi config set k3s-app:replicas 2"
Sleep 500ms
Enter 1
Wait@5s

# ── Preview ───────────────────────────────────────────────────────────────────

Type "echo 'Previewing stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "pulumi preview"
Sleep 500ms
Enter 1
Wait@1m

# ── Deploy ────────────────────────────────────────────────────────────────────

Type "echo 'Deploying stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "pulumi up --yes"
Sleep 500ms
Enter 1
Wait@2m

# ── Inspect resources ─────────────────────────────────────────────────────────

Type "echo 'Inspecting resources'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

# ── Curl the app ──────────────────────────────────────────────────────────────

Type "echo 'Hitting the app through Traefik'"
Sleep 500ms
Enter 1
Sleep 1s

Type "curl -s http://my-app.shivlab.com"
Sleep 500ms
Enter 1
Sleep 4s

# ── Scale up ──────────────────────────────────────────────────────────────────

Type "echo 'Scaling replicas to 3'"
Sleep 500ms
Enter 1
Sleep 1s

Type "pulumi config set k3s-app:replicas 3"
Sleep 500ms
Enter 1
Wait@5s

Type "pulumi up --yes"
Sleep 500ms
Enter 1
Wait@2m

Type "kubectl rollout status deployment/my-app"
Sleep 500ms
Enter 1
Wait@30s

# ── Destroy ───────────────────────────────────────────────────────────────────

Type "echo 'Destroying stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "pulumi destroy --yes"
Sleep 500ms
Enter 1
Wait@2m

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

Type "echo 'Done — all resources removed by Pulumi'"
Sleep 500ms
Enter 1
Sleep 2s