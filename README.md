# Vault Secrets Operator (VSO) for Jenkins and Google Kubernetes Engine (GKE) Gateway

A comprehensive infrastructure solution for deploying Jenkins and SonarQube on Google Kubernetes Engine with automated secret management, TLS certificate renewal, and dual gateway architecture.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Components](#components)
  - [vault/](#vault)
  - [gateway/](#gateway)
  - [jenkins/](#jenkins)
  - [sonarqube/](#sonarqube)
- [Quick Start](#quick-start)
- [Demo](#demo)
- [Prerequisites](#prerequisites)
- [Security Model](#security-model)

## Overview

This project provides a production-ready infrastructure setup that combines HashiCorp Vault for centralized secret management, Vault Secrets Operator for Kubernetes-native secret synchronization, GKE Gateway API for advanced load balancing, and automated deployments for Jenkins and SonarQube with zero-downtime operations.

## Architecture

```
Internet/VPC   ─→   GKE Gateway    ─→   Jenkins/SonarQube Pods
                        ↑                       ↑
                    TLS Certificates   Application Secrets
                        ↑                       ↑
                        └───────────────────────┘
                                    ↑
                            Vault Secrets Operator
                                    ↑
                              HashiCorp Vault
```

The solution supports both external (public internet with IAP authentication) and internal (private VPC network) access patterns. VSO synchronizes both TLS certificates for the gateway and application secrets for Jenkins/SonarQube from Vault to Kubernetes secrets.

## Key Features

- **Zero-Downtime Operations**: Automatic TLS certificate renewal and secret updates without service interruption
- **Enterprise Security**: HashiCorp Vault integration with optimized client licensing and SAML authentication
- **Advanced Networking**: GKE Gateway API with external and internal load balancer support
- **Production Ready**: Cloud SQL integration, custom Docker images, and comprehensive monitoring

## Components

### [vault/](./vault/)
Vault authentication setup and Vault Secrets Operator configuration. Provides centralized secret management with enterprise license optimization, reducing client licensing costs by up to 75% while maintaining security isolation across namespaces.

**Key capabilities:**
- Multi-namespace authentication (AppRole and Kubernetes)
- Single entity optimization for enterprise licensing
- Automated VSO deployment and configuration

### [gateway/](./gateway/)
GKE Gateway API configurations for both external and internal load balancing. Provides automatic TLS certificate renewal with 30-second detection and supports multi-service gateway architecture.

**Key capabilities:**
- Dual gateway architecture (external and internal)
- Automatic TLS certificate renewal from Vault
- Integrated DNS management for public and private zones

### [jenkins/](./jenkins/)
Jenkins deployment with zero-downtime secret updates and automatic configuration reload. Features k8s-sidecar integration that eliminates the need for pod restarts when secrets change.

**Key capabilities:**
- Zero-downtime secret updates without pod restarts
- Automatic Jenkins configuration reload via sidecar
- SAML authentication integration for external access

### [sonarqube/](./sonarqube/)
SonarQube deployment with Cloud SQL PostgreSQL integration and custom Docker image builds. Includes support for private plugin downloads and enterprise database persistence.

**Key capabilities:**
- Cloud SQL PostgreSQL integration for persistence
- Custom Docker images with private plugin support
- Google Cloud IAP protection with SAML authentication

## Quick Start

1. **Configure Vault authentication and VSO**
   ```bash
   cd vault && ./vault-auth-seup.sh
   cd vault-secrets-operator && ./vault-secrets-operator.sh
   ```

2. **Deploy Gateway infrastructure**
   ```bash
   cd gateway && ./enable-gateway-api.sh
   ./configure-gateway-external.sh  # or ./configure-gateway-internal.sh
   ```

3. **Deploy applications**
   ```bash
   cd jenkins && ./configure-jenkins-external.sh
   cd ../sonarqube && ./configure-sonarqube-external.sh
   ```

## Demo
[YouTube Playlist](https://www.youtube.com/playlist?list=PLm9ZfKz5SwIiicaurEWcPBTIUZj7gBR3s)

## Prerequisites

- **Tools**: kubectl, helm, vault, gcloud, docker, jq
- **GCP**: GKE cluster with Gateway API, VPC network, Cloud SQL API, Artifact Registry
- **Vault**: HashiCorp Vault server with admin token and KV-v2 secrets engine
- **Network**: Static IP addresses, DNS zones, appropriate firewall rules

## Security Model

- **Authentication**: Google Cloud IAP with SAML (external) or direct VPC access (internal)
- **Secret Management**: Centralized in Vault with automatic K8s synchronization via VSO
- **Network Security**: TLS 1.2 minimum, restricted SSL policies, namespace isolation
- **Access Control**: RBAC integration with Vault policies and service account bindings

---

*Each subdirectory contains its own detailed README.md with comprehensive setup instructions, troubleshooting guides, and configuration examples.*
