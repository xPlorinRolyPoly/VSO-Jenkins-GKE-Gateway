#!/bin/bash

export PROJECT_SHORT_NAME="nb"
export PROJECT_ID=<YOUR_PROJECT_ID_HERE>
export NETWORK_PROJECT_ID=<YOUR_NETWORK_PROJECT_ID_HERE>
export GKE_CLUSTER_NAME=<YOUR_GKE_CLUSTER_NAME_HERE>
export GKE_REGION="europe-west3"
export SONARQUBE_NAMESPACE="ns-nb-clone-sonarqube"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID

kubectl apply -f vault/

helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
helm upgrade --install -n $SONARQUBE_NAMESPACE nb-clone sonarqube/sonarqube -f override-values.yaml --wait

kubectl apply -f internal/svc/
kubectl apply -f internal/routes/
kubectl apply -f internal/policies/

gcloud compute ssh --project $PROJECT_ID "${PROJECT_SHORT_NAME}-bastion-brm" --zone "europe-west3-b" --command "curl -v https://sonarqube-clone.dev.internal.example.de"
