#!/bin/bash

export PROJECT_SHORT_NAME="nb"
export PROJECT_ID=<YOUR_PROJECT_ID_HERE>
export NETWORK_PROJECT_ID=<YOUR_NETWORK_PROJECT_ID_HERE>
export GKE_CLUSTER_NAME=<YOUR_GKE_CLUSTER_NAME_HERE>
export GKE_REGION="europe-west3"
export SONARQUBE_NAMESPACE="ns-nb-clone-sonarqube"
export GCP_SERVICE_ACCOUNT_NAME="syst-2374-nb-clone-sonarqube"
export K8S_SERVICE_ACCOUNT_NAME="nb-clone-sonarqube"
export SONARQUBE_HELM_CHART_VERSION="2025.4.2"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID
gcloud config list

gcloud iam service-accounts create $GCP_SERVICE_ACCOUNT_NAME \
  --display-name="SYST-2374 NB Clone SonarQube Cloud SQL Service Account"

gcloud iam service-accounts add-iam-policy-binding \
--role="roles/iam.workloadIdentityUser" \
--member="serviceAccount:$PROJECT_ID.svc.id.goog[$SONARQUBE_NAMESPACE/$K8S_SERVICE_ACCOUNT_NAME]" \
"${GCP_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GCP_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GCP_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GCP_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:de-${PROJECT_SHORT_NAME}-sa-ke-jenkins@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

kubectl apply -f vault/

helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube --force-update
helm upgrade --install nb-clone sonarqube/sonarqube \
  -n $SONARQUBE_NAMESPACE \
  --version $SONARQUBE_HELM_CHART_VERSION \
  -f override-values.yaml --wait
# helm history -n $SONARQUBE_NAMESPACE nb-clone
# helm rollback -n $SONARQUBE_NAMESPACE nb-clone --wait

kubectl apply -f external/svc/
kubectl apply -f external/routes/
kubectl apply -f external/policies/

export GKE_PROTECTED_BACKEND_SERVICE=$(gcloud compute backend-services list --format='get(name)' --filter="name~nb-clone-sonarqube")

echo "GKE Protected Backend Service: $GKE_PROTECTED_BACKEND_SERVICE"

gcloud iap web add-iam-policy-binding \
    --resource-type="backend-services" \
    --service=$GKE_PROTECTED_BACKEND_SERVICE \
    --member="group:<YOUR_GOOGLE_GROUP_EMAIL>" \
    --role="roles/iap.httpsResourceAccessor" \
    --project=$PROJECT_ID
  
gcloud iap settings set external/iap/settings.yaml --format=json --project=$PROJECT_ID --resource-type="backend-services" --service=$GKE_PROTECTED_BACKEND_SERVICE

# Cleanup
# kubectl delete -f external/policies/
# kubectl delete -f external/routes/
# kubectl delete -f external/svc/
# helm uninstall -n $SONARQUBE_NAMESPACE nb-clone
# kubectl delete -f vault/
# gcloud iam service-accounts delete syst-2374-nb-clone-sonarqube@${PROJECT_ID}.iam.gserviceaccount.com
