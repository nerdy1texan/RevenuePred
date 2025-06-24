# Enterprise Revenue Prediction Pipeline

An end-to-end machine learning pipeline for ABC Renewables to forecast revenue across multiple renewable energy sites. The pipeline includes synthetic data generation, model training, automated predictions, and visualization.

## 🎯 Features

- Synthetic data generation for renewable energy sites (solar, wind, battery)
- Automated data processing and model training
- Multiple forecasting models (ARIMA, SARIMA, Prophet, Random Forest, LSTM)
- Interactive Streamlit dashboard with confidence intervals
- Full Azure Data Factory orchestration
- Application Insights monitoring
- Cost-optimized architecture (<$50/month)

## 🏗️ Architecture

```mermaid
graph LR
    A[Data Generation] -->|Azure Data Lake| B[Data Processing]
    B --> C[ML Training]
    C --> D[Model Registry]
    D --> E[Model Serving]
    E --> F[Streamlit Dashboard]
    G[Azure Data Factory] -->|Orchestration| A
    G -->|Orchestration| B
    G -->|Orchestration| C
    H[App Insights] -->|Monitoring| A & B & C & D & E & F
```

## 📁 Repository Structure

```
/enterprise-revenue-prediction-pipeline
├── /data_generation/      # Synthetic data generation scripts
├── /data_processing/      # Data cleaning and preprocessing
├── /ml_training/         # Model training pipelines
├── /model_serving/       # Model deployment and serving
├── /streamlit_dashboard/ # Interactive visualization
├── /adf_pipelines/       # Azure Data Factory pipelines
├── /infra/              # Infrastructure as Code
│   ├── /bicep/          # Bicep IaC templates
│   ├── /scripts/        # Deployment scripts
│   └── /docs/           # Additional documentation
├── requirements.txt     # Python dependencies
├── README.md           # This file
└── .gitignore         # Git ignore patterns
```

## 🚀 Getting Started

1. Clone the repository:
```bash
git clone https://github.com/nerdy1texan/RevenuePred.git
cd enterprise-revenue-prediction-pipeline
```

2. Create and activate virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
.\venv\Scripts\activate   # Windows
source /c/Users/mauli/anaconda3/Scripts/activate #GitBash Initialize Conda 
conda activate revenuepred
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Set up Azure Infrastructure:

a. Install Prerequisites:
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Install Bicep tools
az bicep install
```

b. Deploy Infrastructure:
```bash
cd infra/scripts
./deploy-infrastructure.sh
```

c. Set up RBAC:
```bash
./setup-rbac.sh
```

d. Verify Deployment:
```bash
./verify-deployment.sh
```

5. Configure Environment:
The `setup-rbac.sh` script will create a `.env` file with all required credentials:
```
AZURE_STORAGE_CONNECTION_STRING=your_connection_string
AZURE_TENANT_ID=your_tenant_id
AZURE_CLIENT_ID=your_client_id
AZURE_CLIENT_SECRET=your_client_secret
APPINSIGHTS_CONNECTION_STRING=your_connection_string
```

## 🔄 Pipeline Steps

1. **Data Generation**
   - Generate synthetic data for renewable sites
   - Store in Azure Data Lake

2. **Data Processing**
   - Clean and preprocess data
   - Feature engineering
   - Data validation

3. **Model Training**
   - Train multiple forecasting models
   - Model evaluation and selection
   - Model registration

4. **Model Serving**
   - Deploy best performing model
   - Real-time predictions
   - Batch predictions

5. **Visualization**
   - Interactive Streamlit dashboard
   - Revenue forecasts with confidence intervals
   - Performance metrics

## 📊 Data Schema

```python
{
    'Date': 'datetime64[ns]',
    'SiteID': 'string',
    'SiteName': 'string',
    'SiteType': 'string',  # solar, wind, battery
    'EnergyProduced_kWh': 'float64',
    'SpotMarketPrice': 'float64',
    'Revenue': 'float64',
    'WeatherCondition': 'string',
    'DowntimeHours': 'float64',
    'Temperature_C': 'float64',
    'WindSpeed_mps': 'float64'
}
```

## 🛠️ Infrastructure Components

1. **Infrastructure as Code (Bicep templates)**:
   - `main.bicep`: Orchestrates all resource deployments
   - `storage.bicep`: Data Lake Storage Gen2 with lifecycle management
   - `aml.bicep`: Azure ML workspace with compute cluster
   - `adf.bicep`: Data Factory with managed vnet
   - `swa.bicep`: Static Web Apps for dashboard
   - `monitoring.bicep`: Application Insights with alerts

2. **Deployment Scripts**:
   - `deploy-infrastructure.sh`: Main deployment script
   - `setup-rbac.sh`: RBAC and service principal setup
   - `verify-deployment.sh`: Deployment verification

3. **Cost Optimization**:
   - Storage: Uses lifecycle management to move old data to cool tier
   - AML: Auto-shutdown for compute instances
   - ADF: Uses managed vnet for cost-effective integration
   - App Insights: Daily cap of 1GB
   - Budget alerts at 80% threshold
   - Estimated monthly cost: $18-30

4. **Security Features**:
   - RBAC with least privilege access
   - Service Principal for automation
   - Managed identities for services
   - Secure storage access
   - Application Insights for monitoring

## 💰 Cost Management

- Uses Azure free tiers where possible
- Automated resource scaling
- Efficient data storage patterns
- Budget alerts and controls
- Target monthly cost: <$50

## 🔍 Monitoring

- Application Insights integration
- Custom metrics and KPIs
- Automated alerts
- Performance monitoring
- Cost tracking

## 🧪 Testing

Run tests:
```bash
pytest tests/
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

