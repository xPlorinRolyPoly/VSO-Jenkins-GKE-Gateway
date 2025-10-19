#!/bin/bash

export VAULT_ADDR=<YOUR_VAULT_ADDR>

# export VAULT_ADDR=https://localhost:8200
# export VAULT_SKIP_VERIFY=true

export VAULT_TOKEN=<ADMIN_TOKEN>
export VAULT_NAMESPACE=root

vault namespace create sandbox-alpana

export VAULT_NAMESPACE=sandbox-alpana

vault policy write syst-2374-policy syst-2374-policy.hcl

vault secrets enable -path=syst-2374 kv-v2

vault write -format=json identity/entity \
    name="BRM Shared Infra Vault Entity" \
    policies="syst-2374-policy" | \
    jq -r '.data.id' > entity_id.txt

vault auth enable -path=syst-2374-approle approle

vault write -format=json auth/syst-2374-approle/role/syst-2374-reader-role \
    policies="syst-2374-policy"

vault list auth/syst-2374-approle/role

vault read -format=json auth/syst-2374-approle/role/syst-2374-reader-role/role-id | jq -r '.data.role_id' > syst-2374-reader-role-role_id.txt

vault read -format=json sys/auth/syst-2374-approle | jq -r '.data.accessor' > syst-2374-approle-accessor.txt

vault write identity/entity-alias \
    name="$(cat syst-2374-reader-role-role_id.txt)" \
    canonical_id="$(cat entity_id.txt)" \
    mount_accessor="$(cat syst-2374-approle-accessor.txt)"

vault write -format=json -f auth/syst-2374-approle/role/syst-2374-reader-role/secret-id | jq -r '.data.secret_id' > syst-2374-reader-role-secret_id.txt

vault write auth/syst-2374-approle/login \
    role_id="$(cat syst-2374-reader-role-role_id.txt)" \
    secret_id="$(cat syst-2374-reader-role-secret_id.txt)"

vault secrets list

kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/service-accounts/

export VAULT_TOKEN=<ADMIN_TOKEN>

# Configure kubernetes auth method for default namespace

vault auth enable -path=kubernetes-syst-2374-default kubernetes

vault read -format=json sys/auth/kubernetes-syst-2374-default | jq -r '.data.accessor' > kubernetes-syst-2374-default-accessor.txt

DEFAULT_TOKEN_REVIEW_JWT=$(kubectl -n default get secret vault-auth --output='go-template={{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode) 
KUBE_HOST=$(kubectl config view --minify -o jsonpath='{.clusters[].cluster.server}')

vault write auth/kubernetes-syst-2374-default/config \
    token_reviewer_jwt=$DEFAULT_TOKEN_REVIEW_JWT \
    kubernetes_host=$KUBE_HOST \
    kubernetes_ca_cert=$KUBE_CA_CERT \
    disable_issuer_verification=true

vault write auth/kubernetes-syst-2374-default/role/syst-2374-reader-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=default \
    policies=syst-2374-policy \
    ttl=24h \
    alias_name_source=serviceaccount_name

vault write identity/entity-alias \
    name="default/vault-auth" \
    canonical_id="$(cat entity_id.txt)" \
    mount_accessor="$(cat kubernetes-syst-2374-default-accessor.txt)"

# Configure kubernetes auth method for ns-nb-clone-jenkins namespace

vault auth enable -path=kubernetes-syst-2374-jenkins kubernetes

vault read -format=json sys/auth/kubernetes-syst-2374-jenkins | jq -r '.data.accessor' > kubernetes-syst-2374-jenkins-accessor.txt

JENKINS_TOKEN_REVIEW_JWT=$(kubectl -n ns-nb-clone-jenkins get secret vault-auth --output='go-template={{ .data.token }}' | base64 --decode)

vault write auth/kubernetes-syst-2374-jenkins/config \
    token_reviewer_jwt=$JENKINS_TOKEN_REVIEW_JWT \
    kubernetes_host=$KUBE_HOST \
    kubernetes_ca_cert=$KUBE_CA_CERT \
    disable_issuer_verification=true

vault write auth/kubernetes-syst-2374-jenkins/role/syst-2374-reader-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=ns-nb-clone-jenkins \
    policies=syst-2374-policy \
    ttl=24h \
    alias_name_source=serviceaccount_name

vault write identity/entity-alias \
    name="ns-nb-clone-jenkins/vault-auth" \
    canonical_id="$(cat entity_id.txt)" \
    mount_accessor="$(cat kubernetes-syst-2374-jenkins-accessor.txt)"

# Configure kubernetes auth method for ns-nb-clone-sonarqube namespace

vault auth enable -path=kubernetes-syst-2374-sonarqube kubernetes

vault read -format=json sys/auth/kubernetes-syst-2374-sonarqube | jq -r '.data.accessor' > kubernetes-syst-2374-sonarqube-accessor.txt

SONARQUBE_TOKEN_REVIEW_JWT=$(kubectl -n ns-nb-clone-sonarqube get secret vault-auth --output='go-template={{ .data.token }}' | base64 --decode)

vault write auth/kubernetes-syst-2374-sonarqube/config \
    token_reviewer_jwt=$SONARQUBE_TOKEN_REVIEW_JWT \
    kubernetes_host=$KUBE_HOST \
    kubernetes_ca_cert=$KUBE_CA_CERT \
    disable_issuer_verification=true

vault write auth/kubernetes-syst-2374-sonarqube/role/syst-2374-reader-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=ns-nb-clone-sonarqube \
    policies=syst-2374-policy \
    ttl=24h \
    alias_name_source=serviceaccount_name

vault write identity/entity-alias \
    name="ns-nb-clone-sonarqube/vault-auth" \
    canonical_id="$(cat entity_id.txt)" \
    mount_accessor="$(cat kubernetes-syst-2374-sonarqube-accessor.txt)"
