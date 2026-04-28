Output output.mp4

Require echo
Require kubectl
Require vela

Set Shell "zsh"
Set FontSize 22
Set Width 1760
Set Height 950

Type "echo 'KubeVela Demo'"
Sleep 500ms
Enter 1
Sleep 2s

Type "kubectl get pods --namespace vela-system"
Sleep 500ms
Enter 1
Sleep 4s

Type "vela env init prod --namespace prod"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl get namespaces"
Sleep 500ms
Enter 1
Sleep 3s

Type "vela up -f app.yaml"
Sleep 500ms
Enter 1
Sleep 4s

Type "vela status my-application -n prod"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl get pods --namespace default"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl get ingress --namespace default"
Sleep 500ms
Enter 1
Sleep 3s

Type "curl --insecure --silent https://app.local"
Sleep 500ms
Enter 1
Sleep 3s

Type "vela workflow resume my-application -n prod"
Sleep 500ms
Enter 1
Sleep 3s

Type "vela status my-application -n prod"
Sleep 500ms
Enter 1
Wait@2m

Type "kubectl get pods --namespace prod"
Sleep 500ms
Enter 1
Sleep 3s

Type "kubectl get pods --namespace default"
Sleep 500ms
Enter 1
Sleep 3s
