Output output.mp4

Require echo
Require pulumi
Require kubectl

Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950

# ── Login to local state ──────────────────────────────────────────────────────

Type "echo 'Pulumi k3s Demo'"
Sleep 500ms
Enter 1
Sleep 2s

Type "pulumi login --local"
Sleep 500ms
Enter 1
Sleep 3s

# ── Stack init & config ───────────────────────────────────────────────────────

Type "echo 'Initialising stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "PULUMI_CONFIG_PASSPHRASE='' pulumi stack init dev"
Sleep 500ms
Enter 1
Sleep 3s

Type "pulumi config set k3s-app:name my-app"
Sleep 500ms
Enter 1
Sleep 2s

Type "pulumi config set k3s-app:image nginx"
Sleep 500ms
Enter 1
Sleep 2s

Type "pulumi config set k3s-app:replicas 2"
Sleep 500ms
Enter 1
Sleep 2s

# ── Preview ───────────────────────────────────────────────────────────────────

Type "echo 'Previewing stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "PULUMI_CONFIG_PASSPHRASE='' pulumi preview"
Sleep 500ms
Enter 1
Sleep 6s

# ── Deploy ────────────────────────────────────────────────────────────────────

Type "echo 'Deploying stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "PULUMI_CONFIG_PASSPHRASE='' pulumi up --yes"
Sleep 500ms
Enter 1
Sleep 10s

# ── Inspect resources ─────────────────────────────────────────────────────────

Type "echo 'Inspecting resources'"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

Type "PULUMI_CONFIG_PASSPHRASE='' pulumi stack output"
Sleep 500ms
Enter 1
Sleep 3s

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

Type "PULUMI_CONFIG_PASSPHRASE='' pulumi config set k3s-app:replicas 3"
Sleep 500ms
Enter 1
Sleep 2s

Type "PULUMI_CONFIG_PASSPHRASE='' pulumi up --yes"
Sleep 500ms
Enter 1
Sleep 8s

Type "kubectl rollout status deployment/my-app"
Sleep 500ms
Enter 1
Sleep 10s

# ── Destroy ───────────────────────────────────────────────────────────────────

Type "echo 'Destroying stack'"
Sleep 500ms
Enter 1
Sleep 1s

Type "PULUMI_CONFIG_PASSPHRASE='' pulumi destroy --yes"
Sleep 500ms
Enter 1
Sleep 10s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 4s

Type "echo 'Done — all resources removed by Pulumi'"
Sleep 500ms
Enter 1
Sleep 2s