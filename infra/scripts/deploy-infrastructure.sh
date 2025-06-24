#!/bin/bash

# Exit on error
set -e

# Default values
LOCATION="eastus"
STATIC_WEB_APP_LOCATION="eastus2"
ENVIRONMENT="prod"
PROJECT_NAME="abcrenewables"
RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"

# Print usage
usage() {
    echo "Usage: $0 [-l location] [-s static_web_app_location] [-e environment] [-p project_name]"
    echo "  -l: Azure location (default: eastus)"
    echo "  -s: Static Web App location (default: eastus2)"
    echo "  -e: Environment (default: prod)"
    echo "  -p: Project name (default: abcrenewables)"
    exit 1
}

# Parse command line arguments
while getopts "l:s:e:p:" opt; do
    case $opt in
        l) LOCATION="$OPTARG" ;;
        s) STATIC_WEB_APP_LOCATION="$OPTARG" ;;
        e) ENVIRONMENT="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        *) usage ;;
    esac
done

echo "Deploying infrastructure with the following parameters:"
echo "Location: $LOCATION"
echo "Static Web App Location: $STATIC_WEB_APP_LOCATION"
echo "Environment: $ENVIRONMENT"
echo "Project Name: $PROJECT_NAME"
echo "Resource Group: $RG_NAME"

# Create Resource Group
echo "Creating Resource Group..."
az group create --name $RG_NAME --location $LOCATION

# Deploy Bicep template
echo "Deploying Bicep template..."
az deployment group create \
    --resource-group $RG_NAME \
    --template-file ../bicep/main.bicep \
    --parameters \
        location=$LOCATION \
        staticWebAppLocation=$STATIC_WEB_APP_LOCATION \
        environmentName=$ENVIRONMENT \
        projectName=$PROJECT_NAME

# Get deployment outputs
echo "Getting deployment outputs..."
STORAGE_ACCOUNT=$(az deployment group show --resource-group $RG_NAME --name main --query properties.outputs.storageAccountName.value -o tsv)
DATA_FACTORY=$(az deployment group show --resource-group $RG_NAME --name main --query properties.outputs.dataFactoryName.value -o tsv)
AML_WORKSPACE=$(az deployment group show --resource-group $RG_NAME --name main --query properties.outputs.amlWorkspaceName.value -o tsv)

# Setup RBAC
echo "Setting up RBAC..."
# Get Data Factory Managed Identity
ADF_IDENTITY=$(az datafactory show --name $DATA_FACTORY --resource-group $RG_NAME --query identity.principalId -o tsv)

# Assign roles
echo "Assigning roles to Data Factory managed identity..."
az role assignment create \
    --assignee $ADF_IDENTITY \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"

az role assignment create \
    --assignee $ADF_IDENTITY \
    --role "AzureML Data Scientist" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.MachineLearningServices/workspaces/$AML_WORKSPACE"

# Create budget
echo "Setting up budget alert..."
BUDGET_NAME="budget-$PROJECT_NAME-$ENVIRONMENT"
az consumption budget create \
    --budget-name $BUDGET_NAME \
    --amount 50 \
    --time-grain monthly \
    --start-date $(date -d "today" '+%Y-%m-01') \
    --end-date $(date -d "1 year" '+%Y-%m-%d') \
    --resource-group $RG_NAME \
    --notification \
        NotificationName=Budget80Percent \
        NotificationEnabled=true \
        NotificationThreshold=80 \
        ContactEmails=admin@abcrenewables.com

echo "Infrastructure deployment completed successfully!"
echo "Resource Group: $RG_NAME"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Data Factory: $DATA_FACTORY"
echo "ML Workspace: $AML_WORKSPACE" 