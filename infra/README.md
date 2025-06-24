# ABC Renewables ML Pipeline Infrastructure

This directory contains all infrastructure-related code and documentation for the ABC Renewables ML Pipeline.

## 📊 Resource Overview & Costs

| Resource | SKU/Tier | Est. Monthly Cost | Cost Optimization |
|----------|----------|-------------------|-------------------|
| Resource Group | N/A | Free | N/A |
| Data Lake Storage Gen2 | Standard (LRS) | ~$5-10* | Use lifecycle management |
| Azure ML Workspace | Basic | Free** | Use compute instance scheduling |
| Azure Data Factory | Pay-as-you-go | ~$10-15* | Use triggers wisely |
| Static Web Apps | Free tier | Free | Stay within free tier limits |
| Application Insights | Pay-as-you-go | ~$3-5* | Set daily cap |

\* Estimated costs based on typical usage  
\** Basic tier is free, compute costs extra

Total Estimated Monthly Cost: $18-30 (well under $50 budget)

## 🚀 Quick Start

1. Prerequisites:
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Install Bicep tools
az bicep install
```

2. Deploy Infrastructure:
```bash
# Set variables
export RG_NAME="rg-abcrenewables-prod"
export LOCATION="eastus"

# Deploy using main script
./scripts/deploy-infrastructure.sh
```

3. Verify Deployment:
```bash
# Check resource group
az group show --name $RG_NAME

# List all resources
az resource list --resource-group $RG_NAME -o table
```

## 📁 Directory Structure

```
infra/
├── bicep/                    # Bicep IaC templates
│   ├── main.bicep           # Main deployment template
│   ├── storage.bicep        # Data Lake Storage
│   ├── aml.bicep            # Azure ML workspace
│   ├── adf.bicep            # Data Factory
│   ├── swa.bicep           # Static Web Apps
│   └── monitoring.bicep     # App Insights
├── scripts/                  # Deployment scripts
│   ├── deploy-infrastructure.sh    # Main deployment script
│   ├── setup-rbac.sh              # RBAC configuration
│   └── verify-deployment.sh       # Validation script
└── docs/                    # Additional documentation
    └── architecture.md      # Detailed architecture
```

## 🔐 Security & RBAC

The deployment creates a service principal with the following access:
- Data Factory → Data Lake: Storage Blob Data Contributor
- Data Factory → AML: AzureML Data Scientist
- AML → Model Registry: AzureML Model Registry Contributor

## 🔍 Monitoring & Alerts

- Application Insights is configured with:
  - Daily data cap: 1GB
  - Data retention: 90 days
  - Custom metrics for ML pipeline monitoring
  - Cost alerts at 80% threshold

## 💰 Cost Management

1. **Data Lake Storage**
   - Lifecycle management moves old data to cool tier
   - Regular cleanup of temporary files
   - Use LRS for non-critical data

2. **Azure ML**
   - Schedule compute instances to shut down after hours
   - Use low-priority instances where possible
   - Clean up old experiments and models

3. **Data Factory**
   - Use tumbling window triggers instead of polling
   - Optimize pipeline frequency
   - Monitor activity runs

## 🧪 Testing

1. Test Infrastructure Deployment:
```bash
./scripts/verify-deployment.sh
```

2. Validate RBAC:
```bash
./scripts/test-rbac.sh
```

## 📚 Additional Resources

- [Azure Cost Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Best Practices](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/)
- [Security Baseline](https://docs.microsoft.com/security/benchmark/azure/) 