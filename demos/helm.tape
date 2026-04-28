# Output
Output output.mp4

# Requirements
Require echo
Require kubectl
Require helm

# Terminal Settings
Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950

# Intro
Type "echo 'Helm + k3s Demo: Deploying NGINX with Abstractions'"
Sleep 500ms
Enter 1
Sleep 2s

# Check cluster
Type "kubectl get nodes"
Sleep 500ms
Enter 1
Sleep 3s

# Show namespaces (abstraction: isolation)
Type "kubectl get namespaces"
Sleep 500ms
Enter 1
Sleep 3s

# Create namespace
Type "kubectl create namespace demo-nginx"
Sleep 500ms
Enter 1
Sleep 3s

# Verify namespace
Type "kubectl get namespaces"
Sleep 500ms
Enter 1
Sleep 3s

# Add Helm repo
Type "helm repo add bitnami https://charts.bitnami.com/bitnami"
Sleep 500ms
Enter 1
Sleep 3s

Type "helm repo update"
Sleep 500ms
Enter 1
Sleep 3s

# Search chart
Type "helm search repo nginx"
Sleep 500ms
Enter 1
Sleep 3s

# Install with values (abstraction: templating/config)
Type "helm install my-nginx bitnami/nginx --namespace demo-nginx --set service.type=NodePort --set replicaCount=2"
Sleep 500ms
Enter 1
Sleep 6s

# Show Helm releases (abstraction: release mgmt)
Type "helm list -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 3s

# Show pods (abstraction: workload)
Type "kubectl get pods -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 3s

# Show deployments (desired state)
Type "kubectl get deployments -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 3s

# Show services (network abstraction)
Type "kubectl get svc -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 3s

# Describe service for NodePort
Type "kubectl describe svc my-nginx -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 4s

# Show replica scaling abstraction
Type "kubectl scale deployment my-nginx --replicas=3 -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl get pods -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 4s

# Show Helm upgrade abstraction
Type "helm upgrade my-nginx bitnami/nginx --namespace demo-nginx --set replicaCount=1"
Sleep 500ms
Enter 1
Sleep 6s

Type "kubectl get pods -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 4s

# Cleanup (optional abstraction: lifecycle)
Type "helm uninstall my-nginx -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 4s

Type "kubectl get all -n demo-nginx"
Sleep 500ms
Enter 1
Sleep 3s