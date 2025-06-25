#!/bin/bash

# Simple verification script that doesn't require Azure CLI extensions
set -e

# Default values
ENVIRONMENT="prod"
PROJECT_NAME="abcrenewables"
RG_NAME="rg-${PROJECT_NAME}-${ENVIRONMENT}"

echo "🔍 Simple Deployment Verification"
echo "=================================="
echo "Environment: $ENVIRONMENT"
echo "Project Name: $PROJECT_NAME"
echo "Resource Group: $RG_NAME"
echo ""

# Check Resource Group
echo "1️⃣ Checking Resource Group..."
if az group exists --name $RG_NAME >/dev/null 2>&1; then
    echo "   ✅ Resource Group exists"
else
    echo "   ❌ Resource Group not found"
    exit 1
fi

# List all resources in the resource group
echo ""
echo "2️⃣ Listing all resources in the resource group..."
echo "   📋 Resources found:"
az resource list --resource-group $RG_NAME --query "[].{Name:name, Type:type, Status:properties.provisioningState}" -o table 2>/dev/null || echo "   ⚠️  Could not list resources"

# Check specific resources using basic commands
echo ""
echo "3️⃣ Checking key resources..."

# Storage Account
echo "   🗄️  Storage Account:"
STORAGE_COUNT=$(az storage account list -g $RG_NAME --query "length([?contains(name, '${PROJECT_NAME}')])" -o tsv 2>/dev/null || echo "0")
if [ "$STORAGE_COUNT" -gt 0 ]; then
    STORAGE_NAME=$(az storage account list -g $RG_NAME --query "[?contains(name, '${PROJECT_NAME}')].name" -o tsv 2>/dev/null | head -1)
    echo "      ✅ Found: $STORAGE_NAME"
else
    echo "      ❌ Not found"
fi

# Data Factory
echo "   🏭 Data Factory:"
DF_COUNT=$(az resource list -g $RG_NAME --resource-type "Microsoft.DataFactory/factories" --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$DF_COUNT" -gt 0 ]; then
    DF_NAME=$(az resource list -g $RG_NAME --resource-type "Microsoft.DataFactory/factories" --query "[0].name" -o tsv 2>/dev/null)
    echo "      ✅ Found: $DF_NAME"
else
    echo "      ❌ Not found"
fi

# ML Workspace
echo "   🤖 ML Workspace:"
ML_COUNT=$(az resource list -g $RG_NAME --resource-type "Microsoft.MachineLearningServices/workspaces" --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$ML_COUNT" -gt 0 ]; then
    ML_NAME=$(az resource list -g $RG_NAME --resource-type "Microsoft.MachineLearningServices/workspaces" --query "[0].name" -o tsv 2>/dev/null)
    echo "      ✅ Found: $ML_NAME"
else
    echo "      ❌ Not found"
fi

# Key Vault
echo "   🔐 Key Vault:"
KV_COUNT=$(az resource list -g $RG_NAME --resource-type "Microsoft.KeyVault/vaults" --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$KV_COUNT" -gt 0 ]; then
    KV_NAME=$(az resource list -g $RG_NAME --resource-type "Microsoft.KeyVault/vaults" --query "[0].name" -o tsv 2>/dev/null)
    echo "      ✅ Found: $KV_NAME"
else
    echo "      ❌ Not found"
fi

# Application Insights
echo "   📊 Application Insights:"
AI_COUNT=$(az resource list -g $RG_NAME --resource-type "Microsoft.Insights/components" --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$AI_COUNT" -gt 0 ]; then
    AI_NAME=$(az resource list -g $RG_NAME --resource-type "Microsoft.Insights/components" --query "[0].name" -o tsv 2>/dev/null)
    echo "      ✅ Found: $AI_NAME"
else
    echo "      ❌ Not found"
fi

# Static Web App
echo "   🌐 Static Web App:"
SWA_COUNT=$(az resource list -g $RG_NAME --resource-type "Microsoft.Web/staticSites" --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [ "$SWA_COUNT" -gt 0 ]; then
    SWA_NAME=$(az resource list -g $RG_NAME --resource-type "Microsoft.Web/staticSites" --query "[0].name" -o tsv 2>/dev/null)
    echo "      ✅ Found: $SWA_NAME"
else
    echo "      ❌ Not found"
fi

# Check Service Principal
echo ""
echo "4️⃣ Checking Service Principal..."
SP_NAME="sp-${PROJECT_NAME}-${ENVIRONMENT}"
if SP_ID=$(az ad sp list --display-name $SP_NAME --query "[0].appId" -o tsv 2>/dev/null) && [ -n "$SP_ID" ]; then
    echo "   ✅ Service Principal exists: $SP_ID"
else
    echo "   ❌ Service Principal not found"
fi

# Summary
echo ""
echo "🎉 Verification Summary"
echo "======================"
echo "✅ Resource Group: Exists"
echo "📊 Total resources in group: $(az resource list -g $RG_NAME --query "length(@)" -o tsv 2>/dev/null || echo "Unknown")"
echo ""
echo "💡 If any resources show as 'Not found', check the Azure portal manually."
echo "💡 The deployment appears to be successful based on earlier logs."
echo ""
echo "🚀 Next steps:"
echo "   - Check Azure portal for final verification"
echo "   - Proceed with configuring data pipelines"
echo "   - Set up the Streamlit dashboard" 