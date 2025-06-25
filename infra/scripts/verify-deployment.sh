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
echo ""

# Function to run Azure CLI commands with timeout
run_with_timeout() {
    local timeout_duration=30
    local command="$1"
    local description="$2"
    
    echo "⏳ $description..."
    if timeout $timeout_duration bash -c "$command" 2>/dev/null; then
        return 0
    else
        echo "⚠️  $description timed out or failed"
        return 1
    fi
}

# Function to check resource status with timeout
check_resource() {
    local resource_type=$1
    local resource_name=$2
    echo "⏳ Checking $resource_type: $resource_name..."
    
    local status=$(timeout 15 az resource show \
        --resource-group $RG_NAME \
        --name $resource_name \
        --resource-type $resource_type \
        --query "properties.provisioningState" \
        -o tsv 2>/dev/null || echo "Failed")
    
    echo "   Status: $status"
    echo "$status"
}

# Check Resource Group
echo "🔍 Checking Resource Group..."
if run_with_timeout "az group exists --name $RG_NAME" "Resource Group check"; then
    RG_EXISTS=$(az group exists --name $RG_NAME)
    if [ "$RG_EXISTS" = "true" ]; then
        echo "✅ Resource Group exists"
    else
        echo "❌ Resource Group not found"
        exit 1
    fi
else
    echo "❌ Failed to check Resource Group"
    exit 1
fi

echo ""
echo "🔍 Getting resource names..."

# Get resource names with timeouts
echo "⏳ Finding Storage Account..."
STORAGE_ACCOUNT=$(timeout 15 az storage account list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv 2>/dev/null | head -1)

echo "⏳ Finding ML Workspace..."
AML_WORKSPACE=$(timeout 15 az ml workspace list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv 2>/dev/null | head -1)

echo "⏳ Finding Data Factory..."
DATA_FACTORY=$(timeout 15 az datafactory list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv 2>/dev/null | head -1)

echo "⏳ Finding Application Insights..."
APP_INSIGHTS=$(timeout 15 az monitor app-insights component list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv 2>/dev/null | head -1)

echo ""
echo "📋 Found resources:"
echo "   Storage Account: ${STORAGE_ACCOUNT:-'Not found'}"
echo "   ML Workspace: ${AML_WORKSPACE:-'Not found'}"
echo "   Data Factory: ${DATA_FACTORY:-'Not found'}"
echo "   App Insights: ${APP_INSIGHTS:-'Not found'}"

echo ""
echo "🔍 Checking resource status..."

# Check Storage Account
if [ -n "$STORAGE_ACCOUNT" ]; then
    STATUS=$(check_resource "Microsoft.Storage/storageAccounts" $STORAGE_ACCOUNT)
    if [ "$STATUS" = "Succeeded" ]; then
        echo "✅ Storage Account provisioned successfully"
        echo "  🔍 Testing container access..."
        if timeout 10 az storage container list --account-name $STORAGE_ACCOUNT --auth-mode login --query "[].name" -o tsv > /dev/null 2>&1; then
            echo "  ✅ Container access verified"
        else
            echo "  ⚠️  Container access test failed (permissions may still be propagating)"
        fi
    else
        echo "❌ Storage Account provisioning failed or pending"
    fi
else
    echo "❌ Storage Account not found"
fi

# Check AML Workspace
if [ -n "$AML_WORKSPACE" ]; then
    STATUS=$(check_resource "Microsoft.MachineLearningServices/workspaces" $AML_WORKSPACE)
    if [ "$STATUS" = "Succeeded" ]; then
        echo "✅ AML Workspace provisioned successfully"
    else
        echo "❌ AML Workspace provisioning failed or pending"
    fi
else
    echo "❌ AML Workspace not found"
fi

# Check Data Factory
if [ -n "$DATA_FACTORY" ]; then
    STATUS=$(check_resource "Microsoft.DataFactory/factories" $DATA_FACTORY)
    if [ "$STATUS" = "Succeeded" ]; then
        echo "✅ Data Factory provisioned successfully"
    else
        echo "❌ Data Factory provisioning failed or pending"
    fi
else
    echo "❌ Data Factory not found"
fi

# Check Application Insights
if [ -n "$APP_INSIGHTS" ]; then
    STATUS=$(check_resource "Microsoft.Insights/components" $APP_INSIGHTS)
    if [ "$STATUS" = "Succeeded" ]; then
        echo "✅ Application Insights provisioned successfully"
    else
        echo "❌ Application Insights provisioning failed or pending"
    fi
else
    echo "❌ Application Insights not found"
fi

echo ""
echo "🔍 Checking RBAC assignments..."
SP_NAME="sp-${PROJECT_NAME}-${ENVIRONMENT}"
echo "⏳ Looking for Service Principal: $SP_NAME..."

if SP_ID=$(timeout 10 az ad sp list --display-name $SP_NAME --query "[0].appId" -o tsv 2>/dev/null) && [ -n "$SP_ID" ]; then
    echo "✅ Service Principal exists (ID: $SP_ID)"
    echo "⏳ Checking role assignments..."
    if ROLES=$(timeout 10 az role assignment list --assignee $SP_ID --query "[].roleDefinitionName" -o tsv 2>/dev/null); then
        echo "📋 Assigned roles: ${ROLES:-'None found'}"
    else
        echo "⚠️  Could not retrieve role assignments"
    fi
else
    echo "❌ Service Principal not found or query failed"
fi

echo ""
echo "🔍 Checking budget..."
BUDGET_NAME="budget-$PROJECT_NAME-$ENVIRONMENT"
echo "⏳ Looking for budget: $BUDGET_NAME..."

if timeout 10 az consumption budget list --query "[?name=='$BUDGET_NAME']" -o tsv > /dev/null 2>&1; then
    echo "✅ Budget alert configured"
else
    echo "⚠️  Budget alert not found or query failed"
fi

echo ""
echo "🎉 Deployment verification completed!"
echo ""
echo "📊 Summary of key resources:"
echo "   Resource Group: $RG_NAME ✅"
echo "   Storage Account: ${STORAGE_ACCOUNT:-'❌'}"
echo "   ML Workspace: ${AML_WORKSPACE:-'❌'}"
echo "   Data Factory: ${DATA_FACTORY:-'❌'}"
echo "   App Insights: ${APP_INSIGHTS:-'❌'}"
echo ""
echo "💡 If some resources show as 'Not found', they may still be deploying."
echo "💡 You can check the Azure portal for real-time status." 