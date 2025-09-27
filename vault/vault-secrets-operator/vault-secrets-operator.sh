#!/bin/bash

# Configuration
PROJECT_ID=<YOUR_PROJECT_ID>
VSO_NAMESPACE="vault-secrets-operator"
VSO_VERSION="0.10.0"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID

helm repo add hashicorp https://helm.releases.hashicorp.com --force-update

helm upgrade --install vault-secrets-operator hashicorp/vault-secrets-operator \
    --version "$VSO_VERSION" \
    --namespace "$VSO_NAMESPACE" \
    --create-namespace \
    --set defaultVaultConnection.enabled=false \
    --set defaultAuthMethod.enabled=false

kubectl apply -f vault-dev-connection.yaml

kubectl create secret generic vault-dev-syst-2374-approle-secret-id \
    --namespace default \
    --from-literal=id=<YOUR_VAULT_APPROLE_SECRET_ID_HERE>

kubectl apply -f vault-dev-syst-2374-approle.yaml
kubectl apply -f vault-dev-kubernetes-syst-2374-default.yaml
kubectl apply -f vault-dev-kubernetes-syst-2374-jenkins.yaml
kubectl apply -f vault-dev-kubernetes-syst-2374-sonarqube.yaml

# Cleanup
# kubectl delete -f vault-dev-syst-2374-approle.yaml
# kubectl delete -f vault-dev-kubernetes-syst-2374-default.yaml
# kubectl delete -f vault-dev-kubernetes-syst-2374-jenkins.yaml
# kubectl delete -f vault-dev-kubernetes-syst-2374-sonarqube.yaml
# kubectl delete secret vault-dev-syst-2374-approle-secret-id -n default
# kubectl delete -f vault-dev-connection.yaml
# helm uninstall vault-secrets-operator -n "$VSO_NAMESPACE"
# kubectl delete namespace "$VSO_NAMESPACE"
