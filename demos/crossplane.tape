Output output.mp4

Require echo
Require kubectl

Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950

Type "echo 'Crossplane Demo — developer applies a claim, platform does the rest'"
Sleep 500ms
Enter 1
Sleep 2s

Type "cat instance.yaml"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl apply -f instance.yaml"
Sleep 500ms
Enter 1
Wait@1m

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 3s

Type "echo 'Scaling to 3 replicas — developer only touches the claim'"
Sleep 500ms
Enter 1
Sleep 1s

Type "printf 'spec:\n  replicas: 3\n' > patch.yaml"
Sleep 500ms
Enter 1
Sleep 1s

Type "kubectl patch application my-app-instance --type=merge --patch-file patch.yaml"
Sleep 500ms
Enter 1
Wait@30s

Type "kubectl get deployment my-app"
Sleep 500ms
Enter 1
Sleep 3s

Type "curl -s http://nginx.shivlab.com"
Sleep 500ms
Enter 1
Sleep 4s

Type "kubectl delete application my-app-instance"
Sleep 500ms
Enter 1
Wait@30s

Type "kubectl get deployments,services,ingresses"
Sleep 500ms
Enter 1
Sleep 3s

Type "echo 'Done — Crossplane cascaded deletion to all child resources'"
Sleep 500ms
Enter 1
Sleep 2s