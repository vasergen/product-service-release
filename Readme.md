# Product Service Release

This repository contains workflows for managing product service database operations, including database synchronization and active database switching.

## Workflows

### 1. Sync Product Quotes Job (`sync-product-quotes-job.yaml`)

This Kubernetes Job synchronizes product quotes between staging and production databases. It's designed to keep the databases in sync by transferring active product quotes from one environment to another.

#### Process Flow

```mermaid
flowchart TD
    A[Job Start] --> B[Create MongoDB Container]
    B --> C[Install Dependencies]
    C --> D[Install MongoDB Tools, Git, kubectl]
    D --> E[Decode Base64 Scripts]
    E --> F{Scripts Created Successfully?}
    F -->|No| G[Exit with Error]
    F -->|Yes| H[Make Scripts Executable]
    H --> I[Verify sync-active-product-quotes-to-prod.sh exists]
    I --> J{File Exists?}
    J -->|No| K[Exit with Error]
    J -->|Yes| L[Execute Sync Script]
    L --> M[Sync Product Quotes]
    M --> N[Job Complete]
    
    subgraph "Environment Variables"
        O[MONGODB_CONNECTION_STRING_PRODUCTION]
        P[MONGODB_PASSWORD_PRODUCTION]
        Q[MONGODB_CONNECTION_STRING_STAGE]
        R[MONGODB_PASSWORD_STAGE]
        S[SYNC_SCRIPT_CONTENT_B64]
        T[FUNCTIONS_SCRIPT_CONTENT_B64]
        U[PROD_PASSIVE_DB]
    end
    
    L --> O
    L --> P
    L --> Q
    L --> R
    L --> U
```

#### Key Features
- **Base64 Script Injection**: Scripts are injected as base64-encoded environment variables for security
- **Error Handling**: Comprehensive error checking at each step
- **Resource Management**: Memory and CPU limits set to 512Mi/250m
- **TTL**: Job automatically cleaned up after 3 days (259200 seconds)
- **Database Connectivity**: Connects to both staging and production MongoDB clusters

### 2. PIM DB Release Workflow (`pim-db-release.yml`)

This GitHub Actions workflow switches the active database in the product-service by updating the Kubernetes ConfigMap in the production cluster. It's typically used for database release management and failover scenarios.

#### Process Flow

```mermaid
flowchart TD
    A[Manual Trigger] --> B[Checkout Repository]
    B --> C[Configure AWS Credentials]
    C --> D[Update EKS Kubeconfig]
    D --> E[Verify kubectl Context]
    E --> F[Get Current Context]
    F --> G[Execute switch-active-db.sh]
    G --> H[Update ConfigMap]
    H --> I[Active Database Switched]
    I --> J[Workflow Complete]
    
    subgraph "AWS Setup"
        K[AWS Access Key ID]
        L[AWS Secret Access Key]
        M[Region: eu-central-1]
        N[Cluster: production-cluster]
    end
    
    C --> K
    C --> L
    C --> M
    D --> N
    
    subgraph "Kubernetes Operations"
        O[kubectl config update]
        P[ConfigMap modification]
        Q[Service restart/reload]
    end
    
    D --> O
    G --> P
    H --> Q
```

#### Key Features
- **Manual Trigger**: Workflow runs only when manually triggered via workflow_dispatch
- **AWS EKS Integration**: Automatically configures access to production EKS cluster
- **Zero-Downtime Switching**: Updates ConfigMap to switch active database reference
- **Verification Steps**: Multiple verification steps ensure proper kubectl configuration
- **Production Safety**: Operates directly on production cluster with proper AWS credentials

## Usage

### Sync Product Quotes Job
This job is typically scheduled or triggered when you need to synchronize product quotes between environments:
- Ensure all environment variables are properly set in your Kubernetes cluster
- The job will create a temporary pod that handles the synchronization
- Monitor the job logs for any errors during the sync process

### PIM DB Release
This workflow is used for database release management:
1. Navigate to the Actions tab in GitHub
2. Select "PIM DB Release" workflow
3. Click "Run workflow" button
4. The workflow will switch the active database in the production environment

## Prerequisites

- AWS credentials with EKS access permissions
- MongoDB connection strings and passwords for both environments
- Properly configured Kubernetes cluster with necessary permissions
- Base64 encoded sync scripts prepared as environment variables
