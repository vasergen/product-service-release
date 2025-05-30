## PIM Database release

PIM Database release consists of 2 jobs

### 1. Sync Product Quotes Job (`sync-product-quotes-job.yaml`)

This worflow:
- Synchronizes active product quotes from "staging" to "production" databases. This job updates data in the not active database. You can check which database is currently active by checking the "pim-db-active" ConfigMap in the production Kubernetes cluster. This job does not change the active DB, it updates only passive DB.
- Synchronizes S3 files from the "stage" bucket to "production"

#### Process Flow

- Start workflow 
- Connect to K8s
  - Start K8s job to sync MongoDB data
    - Dump active product quotes in MongoDB on stage 
    - Clean up passive production MongoDB DB 
    - Restore dumped stage data into production 
  - Copy S3 files from stage bucket to production   
- Finish

### 2. PIM DB Release Workflow (`pim-db-release.yml`)

This workflow makes passive DB to be active in the "pim-db-active" ConfigMap in the production Kubernetes cluster. Ie: switching `product-service-a` to `product-service-b` or other way around. This job expects `Sync Product Quotes Job` to be executed first, so the passive DB has already data from stage.
