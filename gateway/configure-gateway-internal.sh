#!/bin/bash

export PROJECT_ID=<YOUR_PROJECT_ID>
export NETWORK_PROJECT_ID=<YOUR_NETWORK_PROJECT_ID>
export SHARED_NETWORK_NAME=<YOUR_SHARED_NETWORK_NAME>
export GCP_REGION="europe-west3"
export GATEWAY_NAMESPACE="default"
export GCP_RESOURCE_PREFIX="syst-nb-clone"
export K8S_RESOURCE_PREFIX="nb-clone"
export INTERNAL_STATIC_IP_SUBNET="projects/${NETWORK_PROJECT_ID}/regions/${GCP_REGION}/subnetworks/<YOUR_INTERNAL_STATIC_IP_SUBNET_NAME>"
export JENKINS_PORT=8080
export SONARQUBE_PORT=9000
export RESERVED_PROXY_ONLY_SUBNET_IP_RANGE=<YOUR_RESERVED_PROXY_ONLY_SUBNET_IP_RANGE>
export MANAGED_ZONE_NAME=<YOUR_MANAGED_ZONE_NAME>
export JENKINS_GCP_DNS_RECORD_NAME="jenkins-clone.dev.internal.example.de."
export SONARQUBE_GCP_DNS_RECORD_NAME="sonarqube-clone.dev.internal.example.de."

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $NETWORK_PROJECT_ID

gcloud compute firewall-rules create $GCP_RESOURCE_PREFIX-jenkins-ilb-hc \
    --network=$SHARED_NETWORK_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --source-ranges=$RESERVED_PROXY_ONLY_SUBNET_IP_RANGE \
    --target-tags=<YOUR_TARGET_GKE_NODEPOOL_TAGS> \
    --priority=1000 \
    --rules=tcp:$JENKINS_PORT \
    --description="Allow health checks from GCP Load Balancer to GKE Jenkins"

gcloud compute firewall-rules create $GCP_RESOURCE_PREFIX-sonarqube-ilb-hc \
    --network=$SHARED_NETWORK_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --source-ranges=$RESERVED_PROXY_ONLY_SUBNET_IP_RANGE \
    --target-tags=<YOUR_TARGET_GKE_NODEPOOL_TAGS> \
    --priority=1000 \
    --rules=tcp:$SONARQUBE_PORT \
    --description="Allow health checks from GCP Load Balancer to GKE SonarQube"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID

gcloud compute ssl-policies create $GCP_RESOURCE_PREFIX-regional-ssl-policy \
    --profile RESTRICTED \
    --min-tls-version 1.2 \
    --region=$GCP_REGION \
    --description "Restricted SSL policy for highly secure connections."

gcloud compute addresses create $GCP_RESOURCE_PREFIX-static-ip --region=$GCP_REGION --subnet=$INTERNAL_STATIC_IP_SUBNET

INTERNAL_STATIC_IP=$(gcloud compute addresses describe $GCP_RESOURCE_PREFIX-static-ip --region=$GCP_REGION --format='get(address)')

echo "Internal Static IP named '${GCP_RESOURCE_PREFIX}-static-ip': ${INTERNAL_STATIC_IP}"

kubectl apply -f vault/
kubectl apply -f internal/
# Wait for the Gateway to provision. You can check its status:
kubectl get gateway $K8S_RESOURCE_PREFIX-internal-gateway -n $GATEWAY_NAMESPACE -w

export REGIONAL_INTERNAL_LB_IP=$(kubectl -n $GATEWAY_NAMESPACE get gateway $K8S_RESOURCE_PREFIX-internal-gateway -o json | jq -r '.status.addresses[].value')

echo "Regional internal ALB IP: ${REGIONAL_INTERNAL_LB_IP}"

gcloud config set project $NETWORK_PROJECT_ID

gcloud dns record-sets create "$JENKINS_GCP_DNS_RECORD_NAME" \
    --zone="$MANAGED_ZONE_NAME" \
    --type="A" \
    --ttl="300" \
    --rrdatas="$REGIONAL_INTERNAL_LB_IP"

gcloud dns record-sets create "$SONARQUBE_GCP_DNS_RECORD_NAME" \
    --zone="$MANAGED_ZONE_NAME" \
    --type="A" \
    --ttl="300" \
    --rrdatas="$REGIONAL_INTERNAL_LB_IP"

# cleanup
# gcloud config set project $NETWORK_PROJECT_ID
# gcloud dns record-sets delete "$SONARQUBE_GCP_DNS_RECORD_NAME" \
#     --zone="$MANAGED_ZONE_NAME" \
#     --type="A"
# gcloud dns record-sets delete "$JENKINS_GCP_DNS_RECORD_NAME" \
#     --zone="$MANAGED_ZONE_NAME" \
#     --type="A"
# gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
# gcloud config set project $PROJECT_ID
# kubectl delete -f vault/
# kubectl delete -f internal/
# gcloud compute addresses delete $GCP_RESOURCE_PREFIX-static-ip --region=$GCP_REGION --quiet
# gcloud compute ssl-policies delete $GCP_RESOURCE_PREFIX-regional-ssl-policy --region=$GCP_REGION --quiet
# gcloud config set project $NETWORK_PROJECT_ID
# gcloud compute firewall-rules delete $GCP_RESOURCE_PREFIX-jenkins-ilb-hc --quiet
# gcloud compute firewall-rules delete $GCP_RESOURCE_PREFIX-sonarqube-ilb-hc --quiet
