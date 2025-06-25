#!/bin/bash

# Azure Data Factory Pipeline Deployment Script
# Deploys synthetic data generation pipeline and all dependencies

set -e

# Configuration
RESOURCE_GROUP="rg-abcrenewables-prod"
DATA_FACTORY="adf-abcrenewables-prod"
LOCATION="eastus2"
SUBSCRIPTION_ID="78046962-f2d2-4d17-b14d-f5b1c2d81669"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Set subscription
    az account set --subscription "$SUBSCRIPTION_ID"
    print_status "Using subscription: $SUBSCRIPTION_ID"
}

# Deploy linked services
deploy_linked_services() {
    print_status "Deploying linked services..."
    
    # Deploy Azure Data Lake Storage linked service
    az datafactory linked-service create \
        --factory-name "$DATA_FACTORY" \
        --resource-group "$RESOURCE_GROUP" \
        --name "AzureDataLakeStorage" \
        --properties @../linkedServices/AzureDataLakeStorage.json
    
    # Deploy Azure Batch linked service  
    az datafactory linked-service create \
        --factory-name "$DATA_FACTORY" \
        --resource-group "$RESOURCE_GROUP" \
        --name "AzureBatchLinkedService" \
        --properties @../linkedServices/AzureBatch.json
    
    # Deploy Application Insights linked service
    az datafactory linked-service create \
        --factory-name "$DATA_FACTORY" \
        --resource-group "$RESOURCE_GROUP" \
        --name "ApplicationInsightsLinkedService" \
        --properties @../linkedServices/ApplicationInsights.json
    
    print_status "Linked services deployed successfully"
}

# Deploy datasets
deploy_datasets() {
    print_status "Deploying datasets..."
    
    # Deploy synthetic data output dataset
    az datafactory dataset create \
        --factory-name "$DATA_FACTORY" \
        --resource-group "$RESOURCE_GROUP" \
        --name "SyntheticDataOutput" \
        --properties @../datasets/SyntheticDataOutput.json
    
    # Deploy metadata dataset
    az datafactory dataset create \
        --factory-name "$DATA_FACTORY" \
        --resource-group "$RESOURCE_GROUP" \
        --name "SyntheticDataMetadata" \
        --properties @../datasets/SyntheticDataMetadata.json
    
    print_status "Datasets deployed successfully"
}

# Deploy pipeline
deploy_pipeline() {
    print_status "Deploying main pipeline..."
    
    az datafactory pipeline create \
        --factory-name "$DATA_FACTORY" \
        --resource-group "$RESOURCE_GROUP" \
        --name "generate_synthetic_data_pipeline" \
        --pipeline @../pipelines/generate_synthetic_data_pipeline.json
    
    print_status "Pipeline deployed successfully"
}

# Deploy trigger
deploy_trigger() {
    print_status "Deploying schedule trigger..."
    
    az datafactory trigger create \
        --factory-name "$DATA_FACTORY" \
        --resource-group "$RESOURCE_GROUP" \
        --name "SyntheticDataSchedule" \
        --properties @../triggers/SyntheticDataSchedule.json
    
    print_warning "Trigger created but not started. Use 'az datafactory trigger start' to activate."
}

# Validate deployment
validate_deployment() {
    print_status "Validating deployment..."
    
    # Check linked services
    LINKED_SERVICES=$(az datafactory linked-service list --factory-name "$DATA_FACTORY" --resource-group "$RESOURCE_GROUP" --query "length(@)")
    print_status "Linked services count: $LINKED_SERVICES"
    
    # Check datasets
    DATASETS=$(az datafactory dataset list --factory-name "$DATA_FACTORY" --resource-group "$RESOURCE_GROUP" --query "length(@)")
    print_status "Datasets count: $DATASETS"
    
    # Check pipelines
    PIPELINES=$(az datafactory pipeline list --factory-name "$DATA_FACTORY" --resource-group "$RESOURCE_GROUP" --query "length(@)")
    print_status "Pipelines count: $PIPELINES"
    
    # Check triggers
    TRIGGERS=$(az datafactory trigger list --factory-name "$DATA_FACTORY" --resource-group "$RESOURCE_GROUP" --query "length(@)")
    print_status "Triggers count: $TRIGGERS"
    
    print_status "Deployment validation completed"
}

# Main deployment process
main() {
    print_status "Starting Azure Data Factory pipeline deployment..."
    print_status "Target Data Factory: $DATA_FACTORY in $RESOURCE_GROUP"
    
    check_prerequisites
    deploy_linked_services
    deploy_datasets
    deploy_pipeline
    deploy_trigger
    validate_deployment
    
    print_status "Deployment completed successfully!"
    print_warning "Next steps:"
    echo "1. Configure Key Vault secrets for storage and batch account keys"
    echo "2. Create Logic Apps for email notifications"
    echo "3. Start the trigger: az datafactory trigger start --factory-name $DATA_FACTORY --resource-group $RESOURCE_GROUP --name SyntheticDataSchedule"
    echo "4. Monitor pipeline runs in Azure portal"
}

# Run main function
main "$@" 