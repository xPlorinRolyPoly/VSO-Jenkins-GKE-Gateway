#!/bin/bash

export PROJECT_SHORT_NAME="nb"
export PROJECT_ID=<YOUR_PROJECT_ID_HERE>
export NETWORK_PROJECT_ID=<YOUR_NETWORK_PROJECT_ID_HERE>
export GKE_CLUSTER_NAME=<YOUR_GKE_CLUSTER_NAME_HERE>
export GKE_REGION="europe-west3"
export JENKINS_NAMESPACE="ns-nb-clone-jenkins"
export JENKINS_WORKERS_NAMESPACE="ns-nb-clone-jenkins-workers"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID

kubectl apply -f vault/

helm repo add jenkins https://charts.jenkins.io --force-update
helm upgrade --install $PROJECT_SHORT_NAME-clone jenkins/jenkins -n $JENKINS_NAMESPACE -f saml-override-values.yaml --wait

kubectl apply -f internal/svc/
kubectl apply -f internal/routes/
kubectl apply -f internal/policies/

gcloud compute ssh --project $PROJECT_ID $PROJECT_SHORT_NAME-bastion-brm --zone europe-west3-b

STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}\n" \
  --user "<YOUR_JENKINS_USERNAME_HERE>:<YOUR_JENKINS_API_TOKEN_HERE>" \
  "https://jenkins-clone.dev.internal.example.de/")

echo "Jenkins HTTP Status Code: $STATUS_CODE"
