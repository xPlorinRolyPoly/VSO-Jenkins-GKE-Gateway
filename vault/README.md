# Vault Authentication Setup

This directory contains the configuration and setup scripts for HashiCorp Vault authentication in the VSO-Jenkins-GKE-Gateway project. The setup enables secure secret management for Jenkins and SonarQube deployments on Google Kubernetes Engine (GKE) using Vault Secrets Operator (VSO).

## Overview

The vault setup provides:
- Namespace-based secret isolation for different services
- Kubernetes authentication integration
- AppRole authentication for administrative access
- Policy-based access control
- Multi-namespace secret management

## Files Structure

```
vault/
├── vault-auth-seup.sh                                 # Main setup script for Vault authentication
├── syst-2374-policy.hcl                               # Vault policy defining access permissions
├── k8s/                                               # Kubernetes manifests
│   ├── namespaces/
│   │   ├── ns-nb-clone-jenkins.yaml                   # Jenkins namespaces
│   │   └── ns-nb-clone-sonarqube.yaml                 # SonarQube namespace
│   └── service-accounts/
│       ├── default.yaml                               # Default namespace service account
│       ├── ns-nb-clone-jenkins.yaml                   # Jenkins service account
│       └── ns-nb-clone-sonarqube.yaml                 # SonarQube service account
└── vault-secrets-operator/                            # Vault Secrets Operator (VSO) configurations
    ├── vault-secrets-operator.sh                      # VSO installation and setup script
    ├── vault-dev-connection.yaml                      # VSO Vault connection configuration
    ├── vault-dev-syst-2374-approle.yaml               # AppRole authentication for VSO
    ├── vault-dev-kubernetes-syst-2374-default.yaml    # Default namespace auth
    ├── vault-dev-kubernetes-syst-2374-jenkins.yaml    # Jenkins namespace auth
    └── vault-dev-kubernetes-syst-2374-sonarqube.yaml  # SonarQube namespace auth
```

## Prerequisites

Before running the setup script, ensure you have:

1. **Vault Server Access**: A running HashiCorp Vault server
2. **Admin Credentials**: Vault admin token with appropriate permissions
3. **Kubernetes Cluster**: Access to a GKE cluster with kubectl configured
4. **Required Tools**:
   - `vault` CLI tool
   - `kubectl` CLI tool
   - `jq` for JSON processing
   - `base64` utility
   - `helm` CLI tool (for VSO deployment)
   - `gcloud` CLI tool (for GKE operations)

## Configuration

### Environment Variables

Before running the setup script, configure the environment variables at the top of [`vault-auth-seup.sh`](./vault-auth-seup.sh):
- `VAULT_ADDR`: Your Vault server URL
- `VAULT_TOKEN`: Admin token for Vault operations  
- `VAULT_NAMESPACE`: Root namespace for initial setup
- `VAULT_SKIP_VERIFY`: Optional flag to skip TLS verification (development only)

## Setup Process

The `vault-auth-seup.sh` script performs the following operations:

### 1. Namespace and Policy Setup
- Creates `sandbox-alpana` namespace in Vault
- Applies the `syst-2374-policy` for read access to secrets
- Enables KV-v2 secrets engine at path `syst-2374`

### 2. Entity and AppRole Configuration
- Creates a Vault identity entity "BRM Shared Infra Vault Entity"
- Enables AppRole authentication at path `syst-2374-approle`
- Creates role `syst-2374-reader-role` with read-only policy
- Generates role-id and secret-id for AppRole authentication

### 3. Kubernetes Resources Deployment
- Creates namespaces: `ns-nb-clone-jenkins`, `ns-nb-clone-jenkins-workers`, `ns-nb-clone-sonarqube`
- Deploys service accounts with proper RBAC bindings
- Creates secrets for Kubernetes service account tokens

### 4. Kubernetes Authentication Methods
Configures separate Kubernetes auth methods for each namespace:

#### Default Namespace (`kubernetes-syst-2374-default`)
- Bound to `vault-auth` service account in `default` namespace
- Used for general cluster operations

#### Jenkins Namespace (`kubernetes-syst-2374-jenkins`)
- Bound to `vault-auth` service account in `ns-nb-clone-jenkins` namespace
- Used for Jenkins secret access

#### SonarQube Namespace (`kubernetes-syst-2374-sonarqube`)
- Bound to `vault-auth` service account in `ns-nb-clone-sonarqube` namespace
- Used for SonarQube secret access

## Vault Policy

The [`syst-2374-policy.hcl`](./syst-2374-policy.hcl) defines the access permissions for all authenticated entities:
- **Read and list access** to all secrets under the `syst-2374/*` path
- **List and subscribe capabilities** for the root `syst-2374/` path with event subscription support
- **Read access** to system event subscriptions for monitoring and automation

## Usage

### Running the Setup Script

1. **Edit Configuration**: Update the environment variables in the script header
2. **Make Executable**: `chmod +x vault-auth-seup.sh`
3. **Run Setup**: `./vault-auth-seup.sh`

The script will:
- Configure Vault authentication methods
- Deploy Kubernetes resources
- Set up entity aliases for each namespace
- Generate authentication credentials

### Generated Files

The script creates several temporary files containing credentials:
- `entity_id.txt` - Vault entity ID
- `syst-2374-reader-role-role_id.txt` - AppRole role ID
- `syst-2374-reader-role-secret_id.txt` - AppRole secret ID
- `*-accessor.txt` - Auth method accessors

**Security Note**: These files contain sensitive information and should be handled securely.

## Authentication Flow

### For Kubernetes Workloads
1. Pod uses its service account token
2. Authenticates with namespace-specific Vault auth method
3. Receives Vault token with `syst-2374-policy` permissions
4. Accesses secrets under `syst-2374/*` path

### For Administrative Access
1. Use role-id and secret-id for AppRole authentication
2. Authenticate against `syst-2374-approle` auth method
3. Receive admin-level access to configured resources

## Enterprise License Optimization

This Vault setup is designed to optimize client count for HashiCorp Vault Enterprise licensing by implementing several key strategies:

### Client Count Reduction Strategies

#### 1. **Entity Consolidation**
- **Single Entity Approach**: All authentication methods (AppRole, Kubernetes) are mapped to a single Vault entity: "BRM Shared Infra Vault Entity"
- **Entity Aliases**: Multiple auth methods share the same entity through aliases, counting as one client instead of multiple
- **Benefit**: Reduces client count from potentially 4+ separate clients to 1 unified entity

#### 2. **Shared Service Account Strategy**
- **Consistent Naming**: All namespaces use the same service account name (`vault-auth`)
- **Entity Mapping**: Service accounts from different namespaces map to the same Vault entity via aliases
- **Benefit**: Multiple Kubernetes workloads across namespaces count as a single client

#### 3. **Authentication Method Optimization**
The [`vault-auth-seup.sh`](./vault-auth-seup.sh) script creates entity aliases that map each authentication method to the same canonical entity ID. This technique allows multiple auth methods (AppRole, Kubernetes from different namespaces) to share the same Vault entity, effectively consolidating what would be separate clients into a single billable entity.

#### 4. **Policy Consolidation**
- **Single Policy**: One `syst-2374-policy` serves all authentication methods
- **Shared Permissions**: All entities use the same permission set
- **Benefit**: Simplifies management while maintaining client count efficiency

### Client Count Impact

#### Without Optimization (Traditional Approach)
- AppRole authentication: **1 client**
- Default namespace service account: **1 client**
- Jenkins namespace service account: **1 client**
- SonarQube namespace service account: **1 client**
- **Total: 4 clients**

#### With This Optimization
- Single consolidated entity: **1 client**
- All auth methods as aliases: **0 additional clients**
- **Total: 1 client**

### Vault Client Reduction Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                            TRADITIONAL APPROACH (4 Clients)                          │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│ ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│ │   AppRole Auth  │    │ Default K8s SA  │    │ Jenkins K8s SA  │    │SonarQube SA │ │
│ │                 │    │                 │    │                 │    │             │ │
│ │   Entity: E1    │    │   Entity: E2    │    │   Entity: E3    │    │ Entity: E4  │ │
│ │   Client: 1     │    │   Client: 1     │    │   Client: 1     │    │ Client: 1   │ │
│ └─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────┘ │
│         │                       │                       │                     │      │
│         ▼                       ▼                       ▼                     ▼      │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐  │
│ │                    Total License Cost: 4 Clients                                │  │
│ └─────────────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                            OPTIMIZED APPROACH (1 Client)                             │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│ ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│ │   AppRole Auth  │    │ Default K8s SA  │    │ Jenkins K8s SA  │    │SonarQube SA │ │
│ │                 │    │                 │    │                 │    │             │ │
│ │    Alias: A1    │    │    Alias: A2    │    │    Alias: A3    │    │  Alias: A4  │ │
│ └─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘    └──────┬──────┘ │
│           │                      │                      │                   │        │
│           └──────────────────────┼──────────────────────┼───────────────────┘        │
│                                  │                      │                            │
│                                  └──────────┬───────────┘                            │
│                                             │                                        │
│                                             ▼                                        │
│              ┌─────────────────────────────────────────────────────────┐             │
│              │        Single Consolidated Entity                       │             │
│              │        "BRM Shared Infra Vault Entity"                  │             │
│              │                                                         │             │
│              │        • Entity ID: Shared across all aliases           │             │
│              │        • Policy: syst-2374-policy                       │             │
│              │        • Client Count: 1                                │             │
│              └─────────────────────────────────────────────────────────┘             │
│                                             │                                        │
│                                             ▼                                        │
│ ┌─────────────────────────────────────────────────────────────────────────────────┐  │
│ │                    Total License Cost: 1 Client                                 │  │
│ │                    Cost Reduction: 75%                                          │  │
│ └─────────────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────────────┘

Key Benefits:
├── Entity Consolidation: Multiple auth methods → Single entity
├── Alias Mapping: Each auth method creates alias to same entity
├── Policy Sharing: One policy serves all authentication paths
├── Scalability: New namespaces don't increase client count
└── Cost Efficiency: Up to 75% reduction in licensing costs
```

### Enterprise License Benefits

1. **Cost Efficiency**: Reduces licensing costs by up to 75% for this use case
2. **Scalability**: Adding more namespaces doesn't increase client count
3. **Compliance**: Maintains security isolation while optimizing licensing
4. **Future-Proof**: New services can be added to the same entity pattern

### Implementation Notes

- **Entity ID Persistence**: The `entity_id.txt` file ensures consistent entity reference across all auth methods
- **Alias Management**: Each authentication method creates an alias pointing to the same entity
- **Token Inheritance**: All tokens inherit the same policy and count toward the single entity

### Monitoring Client Count

To verify the optimization is working:

```bash
# Check active clients
vault read sys/internal/counters/tokens

# List entities
vault list identity/entity/id

# Verify entity aliases
vault read identity/entity/id/$(cat entity_id.txt)
```

## Security Considerations

- **Namespace Isolation**: Each service has its own authentication path
- **Principle of Least Privilege**: Policy grants only read access to required paths
- **Token TTL**: Kubernetes tokens expire after 24 hours
- **Service Account Binding**: Authentication is bound to specific service accounts and namespaces

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify Vault server connectivity
   - Check token permissions
   - Ensure Kubernetes cluster access

2. **Permission Denied**
   - Verify policy is correctly applied
   - Check entity alias configuration
   - Ensure service account has proper RBAC permissions

3. **Namespace Issues**
   - Confirm namespaces exist in Kubernetes
   - Verify service account deployment
   - Check ClusterRoleBinding configuration

### Verification Commands

```bash
# List auth methods
vault auth list

# Check policy
vault policy read syst-2374-policy

# Verify Kubernetes auth configuration
vault read auth/kubernetes-syst-2374-jenkins/config

# Test authentication
vault write auth/kubernetes-syst-2374-jenkins/login \
    role=syst-2374-reader-role \
    jwt=$SERVICE_ACCOUNT_TOKEN
```

Use Vault CLI to verify the setup:
- List all configured authentication methods
- Read the applied policy to confirm permissions
- Check Kubernetes authentication configuration for each namespace
- Test authentication using service account tokens with the configured roles

## Vault Secrets Operator (VSO) Integration

The [`vault-secrets-operator/`](./vault-secrets-operator/) directory contains the Kubernetes-native Vault Secrets Operator configuration that provides automatic secret synchronization from Vault to Kubernetes secrets.

### VSO Components

#### Installation and Setup
The [`vault-secrets-operator.sh`](./vault-secrets-operator/vault-secrets-operator.sh) script handles:
- **Helm Installation**: Deploys VSO v0.10.0 using HashiCorp's official Helm chart
- **GKE Configuration**: Sets up Google Cloud project and authentication
- **Namespace Creation**: Creates dedicated `vault-secrets-operator` namespace
- **Custom Configuration**: Disables default connections to use custom auth methods
- **Secret Management**: Creates and manages AppRole secret-id as Kubernetes secret

#### Vault Connection Configuration
The [`vault-dev-connection.yaml`](./vault-secrets-operator/vault-dev-connection.yaml) defines:
- **Connection Specification**: Establishes connection to Vault server
- **Address Configuration**: Points to the Vault server endpoint
- **Namespace Scope**: Deployed in `vault-secrets-operator` namespace for centralized management

#### Authentication Methods
The VSO setup creates multiple VaultAuth resources corresponding to each authentication method configured in the main setup:

##### AppRole Authentication
[`vault-dev-syst-2374-approle.yaml`](./vault-secrets-operator/vault-dev-syst-2374-approle.yaml) provides:
- **Multi-namespace Access**: Allows secrets access across default, Jenkins, and SonarQube namespaces
- **Role-based Authentication**: Uses the `syst-2374-approle` mount point
- **Secret Reference**: References Kubernetes secret containing AppRole secret-id
- **Vault Namespace**: Targets `sandbox-alpana` namespace in Vault

##### Kubernetes Authentication - Default
[`vault-dev-kubernetes-syst-2374-default.yaml`](./vault-secrets-operator/vault-dev-kubernetes-syst-2374-default.yaml) configures:
- **Default Namespace Binding**: Scoped to `default` namespace only
- **Service Account Integration**: Uses `vault-auth` service account
- **Mount Point Mapping**: Connects to `kubernetes-syst-2374-default` auth method
- **Role Assignment**: Uses `syst-2374-reader-role` with read-only permissions

##### Kubernetes Authentication - Jenkins
[`vault-dev-kubernetes-syst-2374-jenkins.yaml`](./vault-secrets-operator/vault-dev-kubernetes-syst-2374-jenkins.yaml) provides:
- **Jenkins Namespace Isolation**: Restricted to `ns-nb-clone-jenkins` namespace
- **CI/CD Integration**: Enables automated secret provisioning for Jenkins workloads
- **Service Account Binding**: Leverages existing `vault-auth` service account
- **Authentication Mount**: Maps to `kubernetes-syst-2374-jenkins` auth method

##### Kubernetes Authentication - SonarQube
[`vault-dev-kubernetes-syst-2374-sonarqube.yaml`](./vault-secrets-operator/vault-dev-kubernetes-syst-2374-sonarqube.yaml) enables:
- **SonarQube Namespace Scope**: Limited to `ns-nb-clone-sonarqube` namespace
- **Code Quality Integration**: Supports automated secret management for SonarQube
- **Consistent Service Account**: Uses the same `vault-auth` pattern
- **Dedicated Mount Point**: Connects to `kubernetes-syst-2374-sonarqube` auth method

### VSO Benefits

#### Automated Secret Management
- **Dynamic Synchronization**: Automatically syncs Vault secrets to Kubernetes secrets
- **Declarative Configuration**: Uses Kubernetes CRDs for secret specification
- **Lifecycle Management**: Handles secret creation, updates, and deletion
- **Error Handling**: Provides status reporting and error recovery

#### Security Enhancements
- **Namespace Isolation**: Each auth method is scoped to specific namespaces
- **Service Account Integration**: Leverages existing RBAC and service account setup
- **Policy Enforcement**: Respects Vault policies defined in the main authentication setup
- **Audit Trail**: Maintains audit logs for secret access and operations

#### Operational Efficiency
- **Kubernetes Native**: Uses standard Kubernetes resources and patterns
- **GitOps Compatible**: All configurations are version-controlled and declarative
- **Monitoring Integration**: Provides metrics and status information
- **Multi-tenancy**: Supports multiple authentication methods and namespaces

### VSO Deployment Process

The deployment follows this sequence:
1. **Helm Installation**: Deploy VSO operator to the cluster
2. **Connection Setup**: Create VaultConnection resource pointing to Vault server
3. **Secret Creation**: Deploy AppRole secret-id as Kubernetes secret
4. **Auth Configuration**: Apply VaultAuth resources for each authentication method
5. **Verification**: Confirm VSO can authenticate and access Vault secrets

### Integration with Main Setup

The VSO configuration is designed to work seamlessly with the main Vault authentication setup:
- **Reuses Authentication Methods**: Leverages auth methods created by `vault-auth-seup.sh`
- **Maintains Entity Optimization**: Preserves the single-entity client count optimization
- **Consistent Naming**: Uses the same service accounts and role names
- **Policy Compliance**: Operates within the permissions defined by `syst-2374-policy`

## Integration

This Vault setup integrates with:
- **Jenkins**: Provides secure access to CI/CD secrets through direct authentication and VSO
- **SonarQube**: Enables secure configuration management with automated secret provisioning
- **GKE Gateway**: Supports certificate and credential management
- **Vault Secrets Operator**: Provides Kubernetes-native automatic secret synchronization and lifecycle management
- **Google Cloud Platform**: Integrates with GKE clusters and GCP identity services

## Maintenance

- **Token Rotation**: Service account tokens auto-rotate based on TTL
- **Policy Updates**: Modify `syst-2374-policy.hcl` and reapply as needed
- **Access Review**: Regularly audit entity aliases and authentication methods
- **VSO Updates**: Monitor VSO operator versions and update using Helm when needed
- **Secret Synchronization**: Monitor VSO secret synchronization status and troubleshoot any failures
- **GKE Cluster Updates**: Ensure VSO compatibility when upgrading GKE cluster versions
- **Cleanup**: Remove temporary credential files after setup completion and unused VSO resources
