# Start colima with Docker enabled
colima start --cpu 4 --memory 16 --network-address

# colima stop
# colima delete

export PROJECT_SHORT_NAME="nb"
export PROJECT_ID=<YOUR_PROJECT_ID>
export ARTIFACT_REGISTRY_HOST=<YOUR_ARTIFACT_REGISTRY_HOST>
export GCP_BUCKET_SQ_PLUGINS="gs://<YOUR_GCP_BUCKET_NAME>"

gcloud config configurations activate <YOUR_GCLOUD_CONFIG_PROFILE>
gcloud auth configure-docker $ARTIFACT_REGISTRY_HOST
gcloud config set project $PROJECT_ID

DOCKER_BUILDKIT=1 docker buildx build \
  --build-arg SONARQUBE_VERSION="25.5.0.107428" \
  -t $ARTIFACT_REGISTRY_HOST/$PROJECT_ID/syst-2374/sonarqube:25.5.0.107428-community .

docker push $ARTIFACT_REGISTRY_HOST/$PROJECT_ID/syst-2374/sonarqube:25.5.0.107428-community

DOCKER_BUILDKIT=1 docker buildx build \
  --build-arg SONARQUBE_VERSION="2025.1.1.104738" \
  --build-arg "SONARQUBE_ZIP_URL=https://binaries.sonarsource.com/CommercialDistribution/sonarqube-developer/sonarqube-developer-2025.1.1.104738.zip" \
  --build-arg "GCP_PROJECT_ID=$PROJECT_ID" \
  --build-arg "SONARQUBE_PLUGIN_GCS_PATHS=$GCP_BUCKET_SQ_PLUGINS/sonar-salesforce-plugin-24.0.13.jar $GCP_BUCKET_SQ_PLUGINS/sonar-codescanlang-plugin-24.0.13.jar" \
  --secret id=gcp_sa_key,src=$HOME/.config/gcloud/nc/global/sa.json \
  -t $ARTIFACT_REGISTRY_HOST/$PROJECT_ID/syst-2374/sonarqube:2025.1.1.104738-developer .

docker push $ARTIFACT_REGISTRY_HOST/$PROJECT_ID/syst-2374/sonarqube:2025.1.1.104738-developer
