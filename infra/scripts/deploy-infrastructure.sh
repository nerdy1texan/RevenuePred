#!/bin/bash

# Exit on error
set -e

# Default values - aligned with setup-rbac.sh
LOCATION="eastus2"
STATIC_WEB_APP_LOCATION="eastus2"
ENVIRONMENT="prod"
PROJECT_NAME="abcrenewables"
RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"

# Print usage
usage() {
    echo "Usage: $0 [-l location] [-s static_web_app_location] [-e environment] [-p project_name]"
    echo "  -l: Azure location (default: eastus2)"
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

# Check if resource group exists (should exist from RBAC setup)
echo "Checking if Resource Group exists..."
RG_EXISTS=$(az group exists --name $RG_NAME)
if [ "$RG_EXISTS" = "false" ]; then
    echo "Creating Resource Group..."
    az group create --name $RG_NAME --location $LOCATION
else
    echo "Resource Group already exists."
fi

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

# Setup RBAC for service-to-service communication
echo "Setting up service-to-service RBAC..."
# Get Data Factory Managed Identity
echo "⏳ Retrieving Data Factory managed identity..."
if ! ADF_IDENTITY=$(timeout 30 az datafactory show --name $DATA_FACTORY --resource-group $RG_NAME --query identity.principalId -o tsv 2>/dev/null); then
    echo "⚠️  Failed to retrieve Data Factory managed identity. Skipping RBAC setup."
    echo "💡 You can set up RBAC manually later if needed."
else
    echo "✅ Data Factory managed identity: $ADF_IDENTITY"

    # Wait for managed identity to propagate
    echo "⏳ Waiting for managed identity propagation (15 seconds)..."
    sleep 15

    # Assign roles with timeout and error handling
    echo "⏳ Assigning Storage Blob Data Contributor role..."
    if timeout 60 az role assignment create \
        --assignee $ADF_IDENTITY \
        --role "Storage Blob Data Contributor" \
        --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" > /dev/null 2>&1; then
        echo "✅ Storage role assigned successfully"
    else
        echo "⚠️  Storage role assignment failed (may already exist or need manual setup)"
    fi

    echo "⏳ Assigning AzureML Data Scientist role..."
    if timeout 60 az role assignment create \
        --assignee $ADF_IDENTITY \
        --role "AzureML Data Scientist" \
        --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.MachineLearningServices/workspaces/$AML_WORKSPACE" > /dev/null 2>&1; then
        echo "✅ ML role assigned successfully"
    else
        echo "⚠️  ML role assignment failed (may already exist or need manual setup)"
    fi
fi

# Create budget (with error handling)
echo ""
echo "⏳ Setting up budget alert..."
BUDGET_NAME="budget-$PROJECT_NAME-$ENVIRONMENT"

# Check if budget already exists
echo "🔍 Checking if budget already exists..."
if timeout 30 az consumption budget list --query "[?name=='$BUDGET_NAME']" -o tsv > /dev/null 2>&1; then
    BUDGET_EXISTS=$(az consumption budget list --query "[?name=='$BUDGET_NAME']" -o tsv)
    if [ -n "$BUDGET_EXISTS" ]; then
        echo "✅ Budget already exists."
    else
        echo "⏳ Creating budget alert..."
        if timeout 60 az consumption budget create \
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
                ContactEmails=admin@abcrenewables.com > /dev/null 2>&1; then
            echo "✅ Budget alert created successfully"
        else
            echo "⚠️  Budget creation failed (this is optional and can be set up manually)"
        fi
    fi
else
    echo "⚠️  Budget check failed (this is optional)"
fi

echo ""
echo "🎉 Infrastructure deployment completed successfully!"
echo ""
echo "📊 Deployed resources:"
echo "   Resource Group: $RG_NAME"
echo "   Storage Account: $STORAGE_ACCOUNT"
echo "   Data Factory: $DATA_FACTORY"
echo "   ML Workspace: $AML_WORKSPACE"
echo ""
echo "🚀 Next step: Run the verification script:"
echo "   bash verify-deployment.sh"
echo ""
echo "💡 Expected verification time: 30-60 seconds" 