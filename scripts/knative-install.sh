kubectl apply -f https://github.com/knative/serving/releases/latest/download/serving-crds.yaml

kubectl apply -f https://github.com/knative/serving/releases/latest/download/serving-core.yaml

kubectl apply -f https://github.com/knative-extensions/net-contour/releases/latest/download/contour.yaml

kubectl apply -f https://github.com/knative-extensions/net-contour/releases/latest/download/net-contour.yaml

kubectl patch configmap/config-network \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{"ingress-class":"contour.ingress.networking.knative.dev"}}'

kubectl --namespace contour-external get service envoy

kubectl get pods -n knative-serving
