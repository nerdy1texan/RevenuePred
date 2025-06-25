#!/bin/bash

# Exit on error
set -e

# Default values
ENVIRONMENT="prod"
PROJECT_NAME="abcrenewables"
LOCATION="eastus2"
RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"

# Print usage
usage() {
    echo "Usage: $0 [-e environment] [-p project_name] [-l location]"
    echo "  -e: Environment (default: prod)"
    echo "  -p: Project name (default: abcrenewables)"
    echo "  -l: Location (default: eastus2)"
    exit 1
}

# Parse command line arguments
while getopts "e:p:l:" opt; do
    case $opt in
        e) ENVIRONMENT="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        l) LOCATION="$OPTARG" ;;
        *) usage ;;
    esac
done

echo "Setting up RBAC with the following parameters:"
echo "Environment: $ENVIRONMENT"
echo "Project Name: $PROJECT_NAME"
echo "Location: $LOCATION"
echo "Resource Group: $RG_NAME"

# Set subscription explicitly
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Using subscription: $SUBSCRIPTION_ID"

# Create resource group first if it doesn't exist
echo "Creating resource group if it doesn't exist..."
az group create --name $RG_NAME --location $LOCATION

# Create Service Principal for the project with subscription scope initially
echo "Creating Service Principal..."
SP_NAME="sp-${PROJECT_NAME}-${ENVIRONMENT}"

# Check if service principal already exists
SP_EXISTS=$(az ad sp list --display-name $SP_NAME --query "length(@)")
if [ "$SP_EXISTS" -gt 0 ]; then
    echo "Service Principal $SP_NAME already exists. Retrieving details..."
    SP_ID=$(az ad sp list --display-name $SP_NAME --query "[0].appId" -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    echo "Note: You'll need to use the existing client secret or create a new one manually."
    echo "Service Principal App ID: $SP_ID"
else
    # Create new service principal with subscription scope
    SP_OUTPUT=$(az ad sp create-for-rbac --name $SP_NAME --role contributor --scopes "/subscriptions/$SUBSCRIPTION_ID")
    
    # Extract values from SP creation
    SP_ID=$(echo $SP_OUTPUT | jq -r .appId)
    SP_SECRET=$(echo $SP_OUTPUT | jq -r .password)
    TENANT_ID=$(echo $SP_OUTPUT | jq -r .tenant)
    
    echo "Service Principal created successfully!"
    echo "App ID: $SP_ID"
fi

# Wait a moment for Azure AD to propagate
echo "Waiting for Azure AD propagation..."
sleep 10

# Create .env file with credentials
echo "Creating .env file..."
ENV_FILE="../../.env"
cat > $ENV_FILE << EOF
# Azure Service Principal Credentials
AZURE_TENANT_ID=$TENANT_ID
AZURE_CLIENT_ID=$SP_ID
$(if [ ! -z "$SP_SECRET" ]; then echo "AZURE_CLIENT_SECRET=$SP_SECRET"; else echo "# AZURE_CLIENT_SECRET=<use_existing_secret_or_create_new>"; fi)

# Subscription and Resource Group
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
RESOURCE_GROUP=$RG_NAME
LOCATION=$LOCATION
PROJECT_NAME=$PROJECT_NAME
ENVIRONMENT=$ENVIRONMENT
EOF

echo "RBAC setup completed successfully!"
echo "Service Principal details saved to .env file"
if [ -z "$SP_SECRET" ]; then
    echo "WARNING: Using existing service principal. You may need to create a new client secret."
fi
echo "IMPORTANT: Keep these credentials secure and never commit them to version control!"
echo ""
echo "Next step: Run the deployment script:"
echo "bash deploy-infrastructure.sh" 