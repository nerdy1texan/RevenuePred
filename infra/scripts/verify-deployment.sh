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

echo "Verifying deployment with the following parameters:"
echo "Environment: $ENVIRONMENT"
echo "Project Name: $PROJECT_NAME"
echo "Resource Group: $RG_NAME"

# Function to check resource status
check_resource() {
    local resource_type=$1
    local resource_name=$2
    echo "Checking $resource_type: $resource_name..."
    
    az resource show \
        --resource-group $RG_NAME \
        --name $resource_name \
        --resource-type $resource_type \
        --query "properties.provisioningState" \
        -o tsv
}

# Check Resource Group
echo "Checking Resource Group..."
RG_EXISTS=$(az group exists --name $RG_NAME)
if [ "$RG_EXISTS" = "true" ]; then
    echo "✅ Resource Group exists"
else
    echo "❌ Resource Group not found"
    exit 1
fi

# Get resource names
STORAGE_ACCOUNT=$(az storage account list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv)
AML_WORKSPACE=$(az ml workspace list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv)
DATA_FACTORY=$(az datafactory list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv)
APP_INSIGHTS=$(az monitor app-insights component show -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv)

# Check Storage Account
STATUS=$(check_resource "Microsoft.Storage/storageAccounts" $STORAGE_ACCOUNT)
if [ "$STATUS" = "Succeeded" ]; then
    echo "✅ Storage Account provisioned successfully"
    # Test container access
    az storage container list \
        --account-name $STORAGE_ACCOUNT \
        --auth-mode login \
        --query "[].name" \
        -o tsv
else
    echo "❌ Storage Account provisioning failed"
fi

# Check AML Workspace
STATUS=$(check_resource "Microsoft.MachineLearningServices/workspaces" $AML_WORKSPACE)
if [ "$STATUS" = "Succeeded" ]; then
    echo "✅ AML Workspace provisioned successfully"
else
    echo "❌ AML Workspace provisioning failed"
fi

# Check Data Factory
STATUS=$(check_resource "Microsoft.DataFactory/factories" $DATA_FACTORY)
if [ "$STATUS" = "Succeeded" ]; then
    echo "✅ Data Factory provisioned successfully"
else
    echo "❌ Data Factory provisioning failed"
fi

# Check Application Insights
STATUS=$(check_resource "Microsoft.Insights/components" $APP_INSIGHTS)
if [ "$STATUS" = "Succeeded" ]; then
    echo "✅ Application Insights provisioned successfully"
else
    echo "❌ Application Insights provisioning failed"
fi

# Check RBAC Assignments
echo "Checking RBAC assignments..."
SP_NAME="sp-${PROJECT_NAME}-${ENVIRONMENT}"
SP_ID=$(az ad sp list --display-name $SP_NAME --query "[0].appId" -o tsv)

if [ -n "$SP_ID" ]; then
    echo "✅ Service Principal exists"
    # Check role assignments
    ROLES=$(az role assignment list --assignee $SP_ID --query "[].roleDefinitionName" -o tsv)
    echo "Assigned roles: $ROLES"
else
    echo "❌ Service Principal not found"
fi

# Check Budget
echo "Checking budget..."
BUDGET_NAME="budget-$PROJECT_NAME-$ENVIRONMENT"
BUDGET=$(az consumption budget list --query "[?name=='$BUDGET_NAME']" -o tsv)
if [ -n "$BUDGET" ]; then
    echo "✅ Budget alert configured"
else
    echo "❌ Budget alert not found"
fi

echo "Deployment verification completed!" 