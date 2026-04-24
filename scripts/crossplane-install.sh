helm repo add crossplane-stable https://charts.crossplane.io/stable

helm install crossplane \
--namespace crossplane-system \
--create-namespace crossplane-stable/crossplane