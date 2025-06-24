#!/bin/bash

# Exit on error
set -e

# Default values
ENVIRONMENT="prod"
PROJECT_NAME="abcrenewables"
RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"

# Print usage
usage() {
    echo "Usage: $0 [-e environment] [-p project_name]"
    echo "  -e: Environment (default: prod)"
    echo "  -p: Project name (default: abcrenewables)"
    exit 1
}

# Parse command line arguments
while getopts "e:p:" opt; do
    case $opt in
        e) ENVIRONMENT="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        *) usage ;;
    esac
done

echo "Setting up RBAC with the following parameters:"
echo "Environment: $ENVIRONMENT"
echo "Project Name: $PROJECT_NAME"
echo "Resource Group: $RG_NAME"

# Create Service Principal for the project
echo "Creating Service Principal..."
SP_NAME="sp-${PROJECT_NAME}-${ENVIRONMENT}"
SP_OUTPUT=$(az ad sp create-for-rbac --name $SP_NAME --role contributor --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME)

# Extract values from SP creation
SP_ID=$(echo $SP_OUTPUT | jq -r .appId)
SP_SECRET=$(echo $SP_OUTPUT | jq -r .password)
TENANT_ID=$(echo $SP_OUTPUT | jq -r .tenant)

# Get resource IDs
STORAGE_ACCOUNT=$(az storage account list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].id" -o tsv)
AML_WORKSPACE=$(az ml workspace list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].id" -o tsv)
DATA_FACTORY=$(az datafactory list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].id" -o tsv)

# Assign roles to Service Principal
echo "Assigning roles to Service Principal..."

# Storage Account roles
az role assignment create \
    --assignee $SP_ID \
    --role "Storage Blob Data Contributor" \
    --scope $STORAGE_ACCOUNT

# AML Workspace roles
az role assignment create \
    --assignee $SP_ID \
    --role "AzureML Data Scientist" \
    --scope $AML_WORKSPACE

# Data Factory roles
az role assignment create \
    --assignee $SP_ID \
    --role "Data Factory Contributor" \
    --scope $DATA_FACTORY

# Create .env file with credentials
echo "Creating .env file..."
cat > ../../.env << EOF
# Azure Service Principal Credentials
AZURE_TENANT_ID=$TENANT_ID
AZURE_CLIENT_ID=$SP_ID
AZURE_CLIENT_SECRET=$SP_SECRET

# Resource Names
RESOURCE_GROUP=$RG_NAME
STORAGE_ACCOUNT_NAME=$(echo $STORAGE_ACCOUNT | cut -d'/' -f9)
AML_WORKSPACE_NAME=$(echo $AML_WORKSPACE | cut -d'/' -f9)
DATA_FACTORY_NAME=$(echo $DATA_FACTORY | cut -d'/' -f9)
EOF

echo "RBAC setup completed successfully!"
echo "Service Principal details saved to .env file"
echo "IMPORTANT: Keep these credentials secure and never commit them to version control!" 