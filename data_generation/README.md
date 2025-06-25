# ABC Renewables Synthetic Data Generator 🌞⚡🔋

This module generates realistic synthetic renewable energy data for the ABC Renewables ML pipeline. It creates data for 6 sites across 3 renewable energy types with realistic patterns, seasonality, and noise.

## 📄 Script Overview

### **🏭 `generate_synthetic_data.py`** - Main Data Generator
**Purpose**: Creates realistic synthetic renewable energy data with proper modeling of seasonal patterns, weather impacts, and market dynamics.

**Key Features**:
- Generates data for 6 predefined renewable energy sites
- Models realistic energy production based on site type (solar/wind/battery)
- Includes weather correlations and seasonal variations
- Introduces realistic missing values (2%) and outliers (1%)
- Outputs timestamped CSV files and JSON summary statistics

**Usage**: `python generate_synthetic_data.py`

### **🧪 `test_data_generator.py`** - Comprehensive Test Suite
**Purpose**: Validates data quality, schema compliance, and business logic of the generated synthetic data.

**Test Categories**:
- **Schema Tests**: Column presence, data types, structure validation
- **Data Quality Tests**: Value ranges, missing values, outlier detection
- **Business Logic Tests**: Revenue calculations, seasonal patterns, correlations
- **Integration Tests**: File I/O, reproducibility, summary statistics

**Usage**: `python test_data_generator.py`

### **🌊 `upload_to_datalake.py`** - Azure Data Lake Integration
**Purpose**: Uploads generated synthetic data to Azure Data Lake Storage Gen2 with proper folder structure and metadata.

**Key Features**:
- Automatic folder structure creation (raw/renewable_energy/YYYY/MM/DD/)
- Metadata and summary statistics upload
- Upload verification and error handling
- Integration with Azure authentication (DefaultAzureCredential)
- Progress tracking and logging

**Usage**: `python upload_to_datalake.py <csv_file> [--summary <summary_file>]`

### **📖 `README.md`** - Complete Documentation
**Purpose**: Comprehensive documentation covering installation, usage, testing, and integration instructions.

**Contains**:
- Quick start guide and local testing instructions
- Data schema and feature descriptions
- Azure Data Lake integration guide
- Troubleshooting and best practices
- Configuration options and customization examples

## 📊 Generated Data Features

### **Sites Configuration**
- **3 Solar Sites**: Desert Sun Solar Farm (50MW), Coastal Solar Array (35MW), Mountain Ridge Solar (60MW)
- **2 Wind Farms**: Prairie Wind Farm (100MW), Offshore Wind Array (150MW)  
- **1 Battery Storage**: Grid Scale Battery (200MWh)

### **Data Schema**
```python
{
    'Date': 'datetime64[ns]',           # Daily timestamps
    'SiteID': 'string',                 # SOLAR001, WIND001, BATT001, etc.
    'SiteName': 'string',               # Human-readable site names
    'SiteType': 'string',               # solar, wind, battery
    'EnergyProduced_kWh': 'float64',    # Daily energy production
    'SpotMarketPrice': 'float64',       # $/MWh electricity price
    'Revenue': 'float64',               # Daily revenue ($)
    'WeatherCondition': 'string',       # Sunny, Cloudy, Rainy, etc.
    'DowntimeHours': 'float64',         # Equipment downtime (0-24h)
    'Temperature_C': 'float64',         # Daily average temperature
    'WindSpeed_mps': 'float64'          # Daily average wind speed
}
```

### **Realistic Modeling**
✅ **Seasonal Patterns**: Solar peaks in summer, wind varies by season  
✅ **Weather Impact**: Production correlates with weather conditions  
✅ **Market Dynamics**: Spot prices with volatility and spikes  
✅ **Equipment Reality**: Maintenance downtime and availability  
✅ **Data Quality**: 2% missing values, 1% outliers  
✅ **Correlation**: Temperature, wind, weather all interconnected  

## 🚀 Quick Start

### **1. Local Testing**

```bash
# Navigate to data generation directory
cd data_generation

# Generate synthetic data (default: 2022-2024)
python generate_synthetic_data.py

# Generate data for specific date range
python generate_synthetic_data.py --start-date 2023-01-01 --end-date 2023-12-31
```

### **2. Run Unit Tests**

```bash
# Run all tests
python test_data_generator.py

# Run specific test
python -m unittest test_data_generator.TestRenewableEnergyDataGenerator.test_schema_validation
```

### **3. Upload to Azure Data Lake**

```bash
# Upload generated data
python upload_to_datalake.py output/abc_renewables_synthetic_data_20250625_092045.csv --summary output/abc_renewables_synthetic_data_20250625_092045_summary.json

# Upload with custom storage account
python upload_to_datalake.py data.csv --storage-account myaccount
```

## 📁 Output Files

### **Generated Files**
- `abc_renewables_synthetic_data_YYYYMMDD_HHMMSS.csv` - Main dataset
- `abc_renewables_synthetic_data_YYYYMMDD_HHMMSS_summary.json` - Statistics and metadata

### **Sample Output Preview**
```
Date        SiteID    SiteName              SiteType  EnergyProduced_kWh  SpotMarketPrice  Revenue
2022-01-01  SOLAR001  Desert Sun Solar Farm solar     245621.3            52.4             12.87
2022-01-01  SOLAR002  Coastal Solar Array   solar     168432.1            52.4             8.83
2022-01-01  WIND001   Prairie Wind Farm     wind      1876543.2           52.4             98.29
...
```

## 🧪 Testing & Validation

### **Schema Tests**
- ✅ All required columns present
- ✅ Correct data types
- ✅ No unexpected columns

### **Data Quality Tests**
- ✅ Value ranges within realistic bounds
- ✅ No negative energy production
- ✅ Reasonable prices ($5-500/MWh)
- ✅ Downtime between 0-24 hours

### **Business Logic Tests**
- ✅ Revenue = Energy × Price ÷ 1000
- ✅ Solar production higher in summer
- ✅ Weather correlates with production
- ✅ Missing values at expected rate (~2%)

### **Run All Tests**
```bash
python test_data_generator.py
```

Expected output:
```
🧪 Running ABC Renewables Data Generator Tests
==================================================
test_schema_validation ... ok
test_data_types ... ok
test_site_configuration ... ok
...
Tests run: 18, Failures: 0, Errors: 0
✅ All tests passed!
```

## 🌊 Azure Data Lake Integration

### **Folder Structure**
Data is uploaded to Azure Data Lake with this structure:
```
raw/
└── renewable_energy/
    └── 2024/
        └── 01/
            └── 15/
                ├── abc_renewables_synthetic_data_20240115_120000.csv
                └── metadata.json
```

### **Prerequisites for Upload**
1. **Azure Authentication**: `az login`
2. **Environment Variables**: Storage account name in `.env`
3. **Permissions**: `Storage Blob Data Contributor` role

### **Upload Examples**
```bash
# Basic upload
python upload_to_datalake.py output/data.csv

# Upload with metadata
python upload_to_datalake.py output/data.csv --summary output/summary.json

# Verify upload
az storage blob list --container-name raw --account-name stabcrenewablesprod
```

## 🔧 Configuration Options

### **Date Range**
```python
generator = RenewableEnergyDataGenerator(
    start_date="2022-01-01",
    end_date="2024-12-31"
)
```

### **Site Customization**
```python
# Modify in generate_synthetic_data.py
self.sites = {
    'SOLAR001': {'name': 'Your Solar Farm', 'type': 'solar', 'capacity_mw': 100},
    # Add more sites...
}
```

### **Data Quality Parameters**
```python
# Adjust missing value rate
combined_data = self._introduce_missing_values(combined_data, missing_rate=0.03)

# Adjust outlier rate
combined_data = self._introduce_outliers(combined_data, outlier_rate=0.02)
```

## 📈 Sample Statistics

For 3-year dataset (2022-2024):
- **Total Records**: 6,574 (6 sites × 1,096 days)
- **Total Energy**: 5.2 billion kWh
- **Total Revenue**: $12.8 million
- **Missing Values**: ~130 values (2.0%)
- **File Size**: ~1.2 MB CSV

## 🔗 Integration with ML Pipeline

### **Next Steps After Generation**
1. **Data Processing**: Clean and feature engineer
2. **Model Training**: Train forecasting models
3. **Model Serving**: Deploy for predictions
4. **Dashboard**: Visualize in Streamlit

### **Data Factory Pipeline**
The generated data integrates with:
- Data validation pipelines
- Feature engineering jobs
- Model training workflows
- Batch prediction processes

## 🚨 Troubleshooting

### **Common Issues**

**Generation Fails**
```bash
# Check dependencies
pip install -r requirements.txt

# Check Python version (3.8+)
python --version
```

**Upload Fails**
```bash
# Check Azure login
az account show

# Check storage account access
az storage account show --name stabcrenewablesprod
```

**Test Failures**
```bash
# Check for missing dependencies
pip install pandas numpy

# Run individual test
python -m unittest test_data_generator.TestRenewableEnergyDataGenerator.test_schema_validation -v
```

### **Performance Notes**
- **3-year dataset**: ~30 seconds generation time
- **1-year dataset**: ~10 seconds generation time
- **Upload time**: ~5-15 seconds depending on file size

## 📚 Dependencies

Core requirements:
```
pandas>=2.0.3
numpy>=1.24.3
azure-storage-blob>=12.17.0
azure-identity>=1.13.0
python-dotenv>=1.0.0
```

See `requirements.txt` for complete list.

## 🏆 Best Practices

1. **Always run tests** before using generated data
2. **Verify upload** to Data Lake before proceeding
3. **Monitor data quality** metrics in summary files
4. **Use consistent date ranges** for model training
5. **Document any customizations** to site configurations 
