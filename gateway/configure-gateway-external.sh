#!/bin/bash

export PROJECT_ID=<YOUR_PROJECT_ID>
export NETWORK_PROJECT_ID=<YOUR_NETWORK_PROJECT_ID>
export GATEWAY_NAMESPACE="default"
export GCP_RESOURCE_PREFIX="syst-nb-clone"
export GCP_RESOURCE_PREFIX_JENKINS="${GCP_RESOURCE_PREFIX}-jenkins"
export GCP_RESOURCE_PREFIX_SONARQUBE="${GCP_RESOURCE_PREFIX}-sonarqube"
export K8S_RESOURCE_PREFIX="nb-clone"
export K8S_RESOURCE_PREFIX_JENKINS="${K8S_RESOURCE_PREFIX}-jenkins"
export K8S_RESOURCE_PREFIX_SONARQUBE="${K8S_RESOURCE_PREFIX}-sonarqube"
export JENKINS_PORT=8080
export SONARQUBE_PORT=9000
export MANAGED_ZONE_NAME=<YOUR_MANAGED_ZONE_NAME>
export JENKINS_GCP_DNS_RECORD_NAME="jenkins-clone.prod.example.de."
export SONARQUBE_GCP_DNS_RECORD_NAME="sonarqube-clone.prod.example.de."

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $NETWORK_PROJECT_ID

gcloud compute firewall-rules create $GCP_RESOURCE_PREFIX-jenkins-lb-hc \
    --network=<YOUR_NETWORK_NAME> \
    --action=ALLOW \
    --direction=INGRESS \
    --source-ranges="35.191.0.0/16,130.211.0.0/22" \
    --target-tags=<YOUR_TARGET_GKE_NODEPOOL_TAGS> \
    --priority=1000 \
    --rules=tcp:$JENKINS_PORT \
    --description="Allow health checks from GCP Load Balancer to GKE Jenkins"

gcloud compute firewall-rules create $GCP_RESOURCE_PREFIX-sonarqube-lb-hc \
    --network=<YOUR_NETWORK_NAME> \
    --action=ALLOW \
    --direction=INGRESS \
    --source-ranges="35.191.0.0/16,130.211.0.0/22" \
    --target-tags=<YOUR_TARGET_GKE_NODEPOOL_TAGS> \
    --priority=1000 \
    --rules=tcp:$SONARQUBE_PORT \
    --description="Allow health checks from GCP Load Balancer to GKE SonarQube"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID

gcloud compute ssl-policies create $GCP_RESOURCE_PREFIX-ssl-policy \
    --profile RESTRICTED \
    --min-tls-version 1.2 \
    --description "Restricted SSL policy for highly secure connections." \
    --global

gcloud compute addresses create $GCP_RESOURCE_PREFIX_JENKINS-static-eip --global
gcloud compute addresses create $GCP_RESOURCE_PREFIX_SONARQUBE-static-eip --global

JENKINS_GLOBAL_STATIC_IP=$(gcloud compute addresses describe $GCP_RESOURCE_PREFIX_JENKINS-static-eip --global --format='get(address)')
SONARQUBE_GLOBAL_STATIC_IP=$(gcloud compute addresses describe $GCP_RESOURCE_PREFIX_SONARQUBE-static-eip --global --format='get(address)')

echo "Global Static IP for Jenkins '${GCP_RESOURCE_PREFIX_JENKINS}-static-eip': ${JENKINS_GLOBAL_STATIC_IP}"
echo "Global Static IP for SonarQube '${GCP_RESOURCE_PREFIX_SONARQUBE}-static-eip': ${SONARQUBE_GLOBAL_STATIC_IP}"

kubectl apply -f vault/
kubectl apply -f external/jenkins/
# Wait for the Gateway to provision. You can check its status:
kubectl get gateway $K8S_RESOURCE_PREFIX_JENKINS-gateway -n $GATEWAY_NAMESPACE -w
kubectl apply -f external/sonarqube/
# Wait for the Gateway to provision. You can check its status:
kubectl get gateway $K8S_RESOURCE_PREFIX_SONARQUBE-gateway -n $GATEWAY_NAMESPACE -w

export JENKINS_GLOBAL_EXTERNAL_LB_IP=$(kubectl -n $GATEWAY_NAMESPACE get gateway $K8S_RESOURCE_PREFIX_JENKINS-gateway -o json | jq -r '.status.addresses[].value')
export SONARQUBE_GLOBAL_EXTERNAL_LB_IP=$(kubectl -n $GATEWAY_NAMESPACE get gateway $K8S_RESOURCE_PREFIX_SONARQUBE-gateway -o json | jq -r '.status.addresses[].value')

echo "Global External ALB IP for Jenkins: ${JENKINS_GLOBAL_EXTERNAL_LB_IP}"
echo "Global External ALB IP for SonarQube: ${SONARQUBE_GLOBAL_EXTERNAL_LB_IP}"

gcloud dns record-sets create "$JENKINS_GCP_DNS_RECORD_NAME" \
    --zone="$MANAGED_ZONE_NAME" \
    --type="A" \
    --ttl="300" \
    --rrdatas=$JENKINS_GLOBAL_EXTERNAL_LB_IP

gcloud dns record-sets create "$SONARQUBE_GCP_DNS_RECORD_NAME" \
    --zone="$MANAGED_ZONE_NAME" \
    --type="A" \
    --ttl="300" \
    --rrdatas=$SONARQUBE_GLOBAL_EXTERNAL_LB_IP

# cleanup
# gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
# gcloud config set project $PROJECT_ID
# gcloud dns record-sets delete "$JENKINS_GCP_DNS_RECORD_NAME" \
#     --zone="$MANAGED_ZONE_NAME" \
#     --type="A"
# gcloud dns record-sets delete "$SONARQUBE_GCP_DNS_RECORD_NAME" \
#     --zone="$MANAGED_ZONE_NAME" \
#     --type="A"
# kubectl delete -f external/jenkins/
# kubectl delete -f external/sonarqube/
# gcloud compute addresses delete $GCP_RESOURCE_PREFIX-static-eip --global --quiet
# gcloud compute ssl-policies delete $GCP_RESOURCE_PREFIX-ssl-policy --global --quiet
# gcloud config set project $NETWORK_PROJECT_ID
# gcloud compute firewall-rules delete $GCP_RESOURCE_PREFIX-jenkins-lb-hc --quiet
# gcloud compute firewall-rules delete $GCP_RESOURCE_PREFIX-sonarqube-lb-hc --quiet
# kubectl delete -f vault/