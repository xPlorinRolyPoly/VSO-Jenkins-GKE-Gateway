#!/bin/bash

export PROJECT_SHORT_NAME="nb"
export PROJECT_ID=<YOUR_PROJECT_ID>
export NETWORK_PROJECT_ID=<YOUR_NETWORK_PROJECT_ID>
export DB_INSTANCE_REGION="europe-west3"
export DB_INSTANCE_NAME="syst-2374-${PROJECT_SHORT_NAME}-clone-sq-in-psql"
export DB_INSTANCE_EDITION="ENTERPRISE"
export DB_INSTANCE_CPU="1"
export DB_INSTANCE_MEMORY="4GB"
export DB_INSTANCE_STORAGE="20GB"
export DB_INSTANCE_STORAGE_TYPE="SSD"
export DB_INSTANCE_VERSION="POSTGRES_17"
export DB_INSTANCE_NETWORK="projects/${NETWORK_PROJECT_ID}/global/networks/<YOUR_VPC_NAME>"
export DB_INSTANCE_IP="--no-assign-ip"
export DB_INSTANCE_SSL_MODE="ENCRYPTED_ONLY"
export DB_INSTANCE_BACKUP="--no-backup"
export DB_INSTANCE_SONARQUBE_USER="sonarqube_user"
export DB_INSTANCE_SONARQUBE_PASSWORD=<YOUR_SONARQUBE_PASSWORD>
export DB_INSTANCE_SONARQUBE_DATABASE="sonarqube_db"
export DB_INSTANCE_ADMIN_USER="postgres"
export DB_INSTANCE_ADMIN_PASSWORD=<YOUR_DB_ADMIN_PASSWORD>

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud config set project $PROJECT_ID

gcloud sql instances create $DB_INSTANCE_NAME \
    --project=$PROJECT_ID \
    --region=$DB_INSTANCE_REGION \
    --database-version=$DB_INSTANCE_VERSION \
    --network=$DB_INSTANCE_NETWORK \
    --cpu=$DB_INSTANCE_CPU \
    --memory=$DB_INSTANCE_MEMORY \
    --edition=$DB_INSTANCE_EDITION \
    --storage-size=$DB_INSTANCE_STORAGE \
    --storage-type=$DB_INSTANCE_STORAGE_TYPE \
    --ssl-mode=$DB_INSTANCE_SSL_MODE \
    $DB_INSTANCE_IP $DB_INSTANCE_BACKUP

gcloud sql users set-password $DB_INSTANCE_ADMIN_USER \
    --instance=$DB_INSTANCE_NAME \
    --project=$PROJECT_ID \
    --password=$DB_INSTANCE_ADMIN_PASSWORD

gcloud sql users create $DB_INSTANCE_SONARQUBE_USER \
    --instance=$DB_INSTANCE_NAME \
    --project=$PROJECT_ID \
    --password=$DB_INSTANCE_SONARQUBE_PASSWORD

gcloud sql databases create $DB_INSTANCE_SONARQUBE_DATABASE \
    --instance=$DB_INSTANCE_NAME \
    --project=$PROJECT_ID

# Connect to database and grant all privileges to sonar user
# GRANT ALL PRIVILEGES ON DATABASE sonarqube_db TO sonarqube_user;