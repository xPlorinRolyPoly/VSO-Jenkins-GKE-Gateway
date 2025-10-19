#!/bin/bash

export PROJECT_ID=<YOUR_PROJECT_ID_HERE>
export NETWORK_PROJECT_ID=<YOUR_NETWORK_PROJECT_ID_HERE>
export GKE_CLUSTER_NAME=<YOUR_GKE_CLUSTER_NAME_HERE>
export GKE_REGION="europe-west3"
export JENKINS_NAMESPACE="ns-nb-clone-jenkins"
export JENKINS_WORKERS_NAMESPACE="ns-nb-clone-jenkins-workers"
export JENKINS_HELM_CHART_VERSION="5.8.86"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID

kubectl apply -f vault/

helm repo add jenkins https://charts.jenkins.io --force-update

helm upgrade --install nb-clone jenkins/jenkins \
    --version $JENKINS_HELM_CHART_VERSION \
    -n $JENKINS_NAMESPACE \
    -f saml-override-values.yaml

kubectl get po -w -n $JENKINS_NAMESPACE

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to be ready..."
sleep 120

kubectl apply -f external/svc/
kubectl apply -f external/routes/
kubectl apply -f external/policies/

export GKE_PROTECTED_BACKEND_SERVICE=$(gcloud compute backend-services list --format='get(name)' --filter="name~nb-clone-jenkins")

echo "GKE Protected Backend Service: $GKE_PROTECTED_BACKEND_SERVICE"

gcloud iap web add-iam-policy-binding \
    --resource-type="backend-services" \
    --service=$GKE_PROTECTED_BACKEND_SERVICE \
    --member="group:<YOUR_GOOGLE_GROUP_EMAIL_HERE>" \
    --role="roles/iap.httpsResourceAccessor" \
    --project=$PROJECT_ID

gcloud iap settings set external/iap/settings.yaml --format=json --project=$PROJECT_ID --resource-type="backend-services" --service=$GKE_PROTECTED_BACKEND_SERVICE

## Cleanup
# kubectl delete -f external/policies/
# kubectl delete -f external/routes/
# kubectl delete -f external/svc/
# kubectl delete -f vault/