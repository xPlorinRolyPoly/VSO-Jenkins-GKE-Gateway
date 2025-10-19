#!/bin/bash

export PROJECT_ID=<YOUR_PROJECT_ID>
export K8S_CLUSTER_NAME=<YOUR_K8S_CLUSTER_NAME>
export K8S_CLUSTER_LOCATION="europe-west3"

gcloud config set project $PROJECT_ID
gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>

# GKE Gateway controller requirements
# https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways#requirements

gcloud container clusters update $K8S_CLUSTER_NAME \
    --location=$K8S_CLUSTER_LOCATION \
    --gateway-api=standard \
    --project=$PROJECT_ID

# GKE Gateway controller limitations
# https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways#limitations