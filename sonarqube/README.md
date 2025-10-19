# SonarQube Configuration and Deployment

This directory contains comprehensive configuration files for deploying SonarQube on Google Kubernetes Engine (GKE) with external and internal access patterns, Vault Secrets Operator (VSO) integration, and custom Docker image builds.

## Prerequisites

- Google Cloud Project with appropriate APIs enabled
- GKE cluster with Gateway API support
- HashiCorp Vault instance with VSO deployed
- Google Artifact Registry for custom image storage
- Cloud SQL API enabled for database provisioning

## Overview

The SonarQube deployment supports both external access (through Google Cloud IAP with SAML authentication) and internal access patterns, utilizing Cloud SQL for database persistence and HashiCorp Vault for secrets management.

## Configuration Files

### Main Configuration

#### [`override-values.yaml`](override-values.yaml)
Helm values override file for the SonarQube chart deployment. Configures:
- Custom Docker image from Google Artifact Registry
- GKE Workload Identity for Cloud SQL access
- Cloud SQL Proxy sidecar container
- Admin password management via Vault secrets
- JDBC connection overrides for PostgreSQL
- SAML authentication settings
- Monitoring and telemetry configuration



### Deployment Scripts

#### [`configure-sonarqube-external.sh`](configure-sonarqube-external.sh)
Automated deployment script for external SonarQube access. Handles:
- GCP service account creation and IAM bindings
- Workload Identity configuration
- Helm chart deployment with custom values
- External service, route, and policy deployment
- Google Cloud IAP configuration and access control
- Backend service IAM policy binding

#### [`configure-sonarqube-internal.sh`](configure-sonarqube-internal.sh)
Simplified deployment script for internal-only SonarQube access. Configures:
- Vault secrets deployment
- Helm chart installation
- Internal service, route, and policy configuration
- Basic connectivity testing via bastion host

### Database Configuration

#### [`db/setup.sh`](db/setup.sh)
Cloud SQL PostgreSQL instance provisioning script. Creates and configures:
- Cloud SQL PostgreSQL 17 instance with enterprise edition
- Private IP networking configuration
- SSL-only encryption mode
- Database and user creation for SonarQube
- Admin user password configuration

### Custom Docker Image

#### [`docker/Dockerfile`](docker/Dockerfile)
Multi-stage Dockerfile for building custom SonarQube images. Features:
- Base image from Eclipse Temurin JRE 17
- Support for private GCS plugin downloads via service account authentication
- Proper user permissions and security contexts
- Plugin installation from Google Cloud Storage buckets
- Support for both Community and Developer editions

#### [`docker/build.sh`](docker/build.sh)
Docker build and push automation script. Supports:
- Colima Docker environment setup
- Multi-architecture builds with BuildKit
- Artifact Registry authentication
- Both Community and Developer edition builds
- Private plugin integration from GCS buckets

#### [`docker/entrypoint.sh`](docker/entrypoint.sh)
Custom entrypoint script providing flexible container startup with default SonarQube execution parameters.

## Network Configuration

### External Access

#### [`external/svc/nb-clone-sonarqube-protected.yaml`](external/svc/nb-clone-sonarqube-protected.yaml)
Kubernetes service definition for IAP-protected external access to SonarQube pods.

#### [`external/routes/http-routes.yaml`](external/routes/http-routes.yaml)
Gateway API HTTPRoute configuration for external access. Defines:
- Multiple hostname support for different domains
- Path-based routing rules
- Backend service references for protected and unprotected endpoints
- Special routing for API endpoints and OAuth callbacks

#### [`external/policies/backend-policies.yaml`](external/policies/backend-policies.yaml)
GCP Backend Policy configurations for external services. Includes:
- Cloud Armor security policy integration
- Google Cloud IAP enablement
- OAuth2 client configuration

#### [`external/policies/health-check-policies.yaml`](external/policies/health-check-policies.yaml)
Health check policy definitions for both protected and unprotected external services, using SonarQube's system status API endpoint.

#### [`external/iap/settings.yaml`](external/iap/settings.yaml)
Identity-Aware Proxy access control settings defining allowed domains for SonarQube access.

### Internal Access

#### [`internal/svc/nb-clone-sonarqube-internal.yaml`](internal/svc/nb-clone-sonarqube-internal.yaml)
Kubernetes service definition for internal cluster access to SonarQube.

#### [`internal/routes/http-routes.yaml`](internal/routes/http-routes.yaml)
Internal HTTPRoute configuration for cluster-internal access with simplified routing rules.

#### [`internal/policies/health-check-policies.yaml`](internal/policies/health-check-policies.yaml)
Health check policy for internal service monitoring.

## Secrets Management

All Vault secrets are managed through the Vault Secrets Operator (VSO) and reference the HashiCorp Vault instance for secure credential storage.

#### [`vault/vault-dev-secret-syst-2374-sonarqube-admin.yaml`](vault/vault-dev-secret-syst-2374-sonarqube-admin.yaml)
VSO secret definition for SonarQube administrator credentials. Manages:
- Current admin password
- Previous admin password for rotation scenarios
- Automatic StatefulSet rollout restart on secret updates

#### [`vault/vault-dev-secret-syst-2374-sonarqube-db.yaml`](vault/vault-dev-secret-syst-2374-sonarqube-db.yaml)
Database connection credentials from Vault for PostgreSQL access.

#### [`vault/vault-dev-secret-syst-2374-sonarqube-iap.yaml`](vault/vault-dev-secret-syst-2374-sonarqube-iap.yaml)
OAuth2 client secret for Google Cloud IAP integration.

#### [`vault/vault-dev-secret-syst-2374-sonarqube-saml.yaml`](vault/vault-dev-secret-syst-2374-sonarqube-saml.yaml)
SAML authentication configuration including:
- Provider certificate management
- Azure AD/Microsoft identity provider settings
- User attribute mappings for login, name, email, and groups
- Dynamic certificate content handling with proper formatting

## Architecture Components

### Security Model
- **External Access**: Protected by Google Cloud IAP with SAML authentication via Azure AD
- **Internal Access**: Direct cluster access for internal services
- **Database**: Cloud SQL PostgreSQL with private IP and SSL enforcement
- **Secrets**: HashiCorp Vault integration via VSO for credential management

### High Availability
- **Storage**: Persistent volumes for SonarQube data and extensions
- **Database**: Managed Cloud SQL with automated backups (when enabled)
- **Networking**: Load balancer integration with health checks
- **Monitoring**: Built-in health check endpoints and monitoring passcode

### Custom Features
- **Plugin Management**: Automated plugin installation from private GCS buckets
- **Image Customization**: Multi-stage Docker builds with security contexts
- **Secret Rotation**: VSO-managed secret updates with pod restart automation
- **Multi-Environment**: Support for both community and developer editions

## Deployment Order

1. **Database Setup**: Run [`db/setup.sh`](db/setup.sh) to provision Cloud SQL instance
2. **External Deployment**: Execute [`configure-sonarqube-external.sh`](configure-sonarqube-external.sh) for full external access
3. **Internal Deployment**: Run [`configure-sonarqube-internal.sh`](configure-sonarqube-internal.sh) for internal access (optional)

## Known Issues

### VSO Secrets Management and Password Rotation

SonarQube, unlike Jenkins (which supports dynamic config reloading via plugins or API for certain settings), does not have a built-in mechanism for hot-reloading or automatically updating runtime configurations like the admin password without a full application restart and explicit intervention. Most of SonarQube's core configurations (including user credentials) are loaded at startup from `sonar.properties` and persisted in its internal database (the external PostgreSQL instance). Changes to external secrets or properties files alone won't propagate without additional steps, as the application doesn't poll for or reload them dynamically.

#### Key Behavior for Admin Password Rotation

Based on the official SonarQube Helm chart (from SonarSource), the `setAdminPassword` feature enabled in [`override-values.yaml`](override-values.yaml) is specifically designed for **initial setup only**:

- It creates a Kubernetes Job (via a Helm post-install hook named `change-admin-password-hook`) that runs *once* during the initial `helm install` (or `--install` upgrade that acts like an install).
- This Job:
  - Starts a temporary SonarQube pod
  - Uses the default "admin" credentials to log in via the SonarQube Web API
  - Updates the admin user's password to the value from the specified secret (`nb-clone-sonarqube-admin`, pulling the `password` key)
  - The password is then hashed and stored permanently in the SonarQube database (table `users`, column `crypted_password`)
- The Vault Secrets Operator (VSO) setup correctly triggers a StatefulSet rollout restart on secret changes (via `rolloutRestartTargets`), but this only restarts the pods—it doesn't re-run the helm hooks or update the DB-stored password. The old hashed password remains in the DB, so logins continue working with the prior value.

**In summary**: Password changes through VSO fail because the Helm hook isn't re-executed on vault secret change. VSO handles secret syncing well, but SonarQube's database persistence overrides it for user authentication.