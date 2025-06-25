#!/usr/bin/env python3
"""
ABC Renewables Synthetic Data Generator
======================================

Generates realistic daily renewable energy data for multiple sites with:
- 3 Solar sites
- 2 Wind farms  
- 1 Battery storage unit

Includes trend, seasonality, weather impact, and realistic noise patterns.
"""

import os
import sys
import pandas as pd
import numpy as np
import logging
from datetime import datetime, timedelta
import json
from typing import Dict, List, Tuple, Optional
import warnings
warnings.filterwarnings('ignore')

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class RenewableEnergyDataGenerator:
    """Generate synthetic renewable energy data for ABC Renewables"""
    
    def __init__(self, start_date: str = "2022-01-01", end_date: str = "2024-12-31"):
        """
        Initialize the data generator
        
        Args:
            start_date: Start date in YYYY-MM-DD format
            end_date: End date in YYYY-MM-DD format
        """
        self.start_date = pd.to_datetime(start_date)
        self.end_date = pd.to_datetime(end_date)
        self.date_range = pd.date_range(self.start_date, self.end_date, freq='D')
        
        # Site configurations
        self.sites = {
            'SOLAR001': {'name': 'Desert Sun Solar Farm', 'type': 'solar', 'capacity_mw': 50},
            'SOLAR002': {'name': 'Coastal Solar Array', 'type': 'solar', 'capacity_mw': 35},
            'SOLAR003': {'name': 'Mountain Ridge Solar', 'type': 'solar', 'capacity_mw': 60},
            'WIND001': {'name': 'Prairie Wind Farm', 'type': 'wind', 'capacity_mw': 100},
            'WIND002': {'name': 'Offshore Wind Array', 'type': 'wind', 'capacity_mw': 150},
            'BATT001': {'name': 'Grid Scale Battery', 'type': 'battery', 'capacity_mwh': 200}
        }
        
        # Weather conditions
        self.weather_conditions = ['Sunny', 'Partly Cloudy', 'Cloudy', 'Rainy', 'Stormy', 'Foggy']
        
        logger.info(f"Initialized data generator for {len(self.sites)} sites from {start_date} to {end_date}")
    
    def _generate_spot_market_price(self, dates: pd.DatetimeIndex) -> np.ndarray:
        """Generate realistic spot market electricity prices"""
        np.random.seed(42)
        
        # Base price with seasonal trend
        base_price = 45  # $/MWh
        
        # Seasonal component (higher in summer/winter)
        seasonal = 10 * np.sin(2 * np.pi * dates.dayofyear / 365.25) + \
                  8 * np.sin(4 * np.pi * dates.dayofyear / 365.25)
        
        # Weekly pattern (higher on weekdays)
        weekly = 5 * (dates.dayofweek < 5).astype(float)
        
        # Time trend (slight increase over years)
        years_since_start = (dates - self.start_date).days / 365.25
        trend = 2 * years_since_start
        
        # Random volatility
        volatility = np.random.normal(0, 8, len(dates))
        
        # Occasional price spikes
        spike_prob = 0.05
        spikes = np.random.random(len(dates)) < spike_prob
        spike_values = np.random.uniform(20, 80, len(dates)) * spikes
        
        prices = base_price + seasonal + weekly + trend + volatility + spike_values
        
        # Ensure no negative prices
        prices = np.maximum(prices, 5)
        
        return prices
    
    def _generate_weather_data(self, dates: pd.DatetimeIndex) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Generate weather conditions, temperature, and wind speed"""
        np.random.seed(123)
        
        # Temperature with seasonal variation
        avg_temp = 15  # Base temperature in Celsius
        seasonal_temp = 12 * np.sin(2 * np.pi * (dates.dayofyear - 80) / 365.25)
        daily_variation = np.random.normal(0, 5, len(dates))
        temperature = avg_temp + seasonal_temp + daily_variation
        
        # Wind speed (correlated with season and weather)
        base_wind = 8  # m/s
        seasonal_wind = 3 * np.sin(2 * np.pi * (dates.dayofyear - 120) / 365.25)
        wind_variation = np.random.gamma(2, 2, len(dates))  # Gamma distribution for wind
        wind_speed = np.maximum(base_wind + seasonal_wind + wind_variation, 0)
        
        # Weather conditions (influenced by temperature and wind)
        weather_probs = np.column_stack([
            0.4 + 0.2 * (temperature > 20),  # Sunny
            0.25 * np.ones(len(dates)),  # Partly Cloudy
            0.2 * np.ones(len(dates)),   # Cloudy
            0.1 + 0.1 * (temperature < 10),  # Rainy
            0.03 + 0.02 * (wind_speed > 15), # Stormy
            0.02 + 0.03 * (temperature < 5)  # Foggy
        ])
        
        # Normalize probabilities
        weather_probs = weather_probs / weather_probs.sum(axis=1, keepdims=True)
        
        # Sample weather conditions
        weather_conditions = []
        for i, probs in enumerate(weather_probs):
            weather_conditions.append(
                np.random.choice(self.weather_conditions, p=probs)
            )
        
        return np.array(weather_conditions), temperature, wind_speed
    
    def _generate_energy_production(self, site_id: str, site_info: Dict, 
                                  dates: pd.DatetimeIndex, weather: np.ndarray, 
                                  temperature: np.ndarray, wind_speed: np.ndarray) -> np.ndarray:
        """Generate energy production for a specific site"""
        np.random.seed(hash(site_id) % 2**32)
        
        site_type = site_info['type']
        capacity = site_info.get('capacity_mw', site_info.get('capacity_mwh', 50))
        
        if site_type == 'solar':
            return self._generate_solar_production(dates, weather, temperature, capacity)
        elif site_type == 'wind':
            return self._generate_wind_production(dates, weather, wind_speed, capacity)
        elif site_type == 'battery':
            return self._generate_battery_production(dates, weather, capacity)
        else:
            raise ValueError(f"Unknown site type: {site_type}")
    
    def _generate_solar_production(self, dates: pd.DatetimeIndex, weather: np.ndarray, 
                                 temperature: np.ndarray, capacity: float) -> np.ndarray:
        """Generate solar energy production"""
        # Base production (seasonal with peak in summer)
        seasonal_factor = 0.7 + 0.3 * np.sin(2 * np.pi * (dates.dayofyear - 80) / 365.25)
        
        # Weather impact on solar
        weather_factor = np.array([
            0.95 if w == 'Sunny' else
            0.75 if w == 'Partly Cloudy' else
            0.45 if w == 'Cloudy' else
            0.2 if w == 'Rainy' else
            0.1 if w == 'Stormy' else
            0.3 if w == 'Foggy' else 0.5
            for w in weather
        ])
        
        # Temperature effect (efficiency decreases with high temperature)
        temp_factor = np.maximum(0.5, 1 - 0.01 * np.maximum(0, temperature - 25))
        
        # Daily variation and noise
        daily_variation = np.random.uniform(0.8, 1.2, len(dates))
        
        # Hours of daylight equivalent (daily energy)
        base_hours = 8 + 4 * seasonal_factor
        
        production = capacity * base_hours * seasonal_factor * weather_factor * temp_factor * daily_variation
        
        return np.maximum(production, 0)
    
    def _generate_wind_production(self, dates: pd.DatetimeIndex, weather: np.ndarray, 
                                wind_speed: np.ndarray, capacity: float) -> np.ndarray:
        """Generate wind energy production"""
        # Wind power curve (cubic relationship with speed, with cut-in and cut-out)
        cut_in = 3.5  # m/s
        rated_speed = 12  # m/s
        cut_out = 25  # m/s
        
        # Calculate capacity factor based on wind speed
        capacity_factor = np.where(
            wind_speed < cut_in, 0,
            np.where(
                wind_speed < rated_speed, 
                (wind_speed / rated_speed) ** 3,
                np.where(wind_speed < cut_out, 1, 0)
            )
        )
        
        # Weather impact on wind
        weather_factor = np.array([
            0.8 if w == 'Sunny' else
            0.9 if w == 'Partly Cloudy' else
            1.0 if w == 'Cloudy' else
            1.1 if w == 'Rainy' else
            1.3 if w == 'Stormy' else
            0.7 if w == 'Foggy' else 1.0
            for w in weather
        ])
        
        # Daily variation
        daily_variation = np.random.uniform(0.85, 1.15, len(dates))
        
        # 24 hours operation
        production = capacity * 24 * capacity_factor * weather_factor * daily_variation
        
        return np.maximum(production, 0)
    
    def _generate_battery_production(self, dates: pd.DatetimeIndex, weather: np.ndarray, 
                                   capacity: float) -> np.ndarray:
        """Generate battery storage discharge (appears as production)"""
        # Battery operates strategically (higher discharge during peak demand)
        
        # Seasonal pattern (more discharge in summer/winter)
        seasonal_factor = 0.4 + 0.3 * np.abs(np.sin(2 * np.pi * dates.dayofyear / 365.25))
        
        # Weekly pattern (more discharge on weekdays)
        weekly_factor = 0.8 + 0.4 * (dates.dayofweek < 5).astype(float)
        
        # Weather impact (more discharge during poor renewable weather)
        weather_factor = np.array([
            0.3 if w == 'Sunny' else
            0.5 if w == 'Partly Cloudy' else
            0.8 if w == 'Cloudy' else
            1.0 if w == 'Rainy' else
            1.2 if w == 'Stormy' else
            0.9 if w == 'Foggy' else 0.6
            for w in weather
        ])
        
        # Random operational decisions
        operational_factor = np.random.uniform(0.3, 1.0, len(dates))
        
        # Assume 4-hour average discharge duration per day
        discharge_hours = 4
        production = capacity * discharge_hours * seasonal_factor * weekly_factor * weather_factor * operational_factor
        
        return np.maximum(production, 0)
    
    def _generate_downtime(self, dates: pd.DatetimeIndex, site_type: str) -> np.ndarray:
        """Generate realistic downtime hours"""
        np.random.seed(456)
        
        # Base maintenance schedules
        maintenance_prob = {
            'solar': 0.02,  # 2% chance per day
            'wind': 0.03,   # 3% chance per day
            'battery': 0.01 # 1% chance per day
        }
        
        # Random maintenance events
        maintenance_days = np.random.random(len(dates)) < maintenance_prob[site_type]
        
        # Maintenance duration (when it occurs)
        maintenance_hours = np.where(
            maintenance_days,
            np.random.uniform(2, 12, len(dates)),  # 2-12 hours
            0
        )
        
        # Weather-related outages
        weather_outage_hours = np.random.exponential(0.5, len(dates))
        weather_outage_hours = np.where(weather_outage_hours > 3, 0, weather_outage_hours)
        
        total_downtime = maintenance_hours + weather_outage_hours
        
        # Cap at 24 hours per day
        return np.minimum(total_downtime, 24)
    
    def _introduce_missing_values(self, df: pd.DataFrame, missing_rate: float = 0.02) -> pd.DataFrame:
        """Introduce realistic missing values"""
        np.random.seed(789)
        
        # Columns that can have missing values
        nullable_columns = ['EnergyProduced_kWh', 'Temperature_C', 'WindSpeed_mps']
        
        for col in nullable_columns:
            if col in df.columns:
                missing_mask = np.random.random(len(df)) < missing_rate
                df.loc[missing_mask, col] = np.nan
        
        return df
    
    def _introduce_outliers(self, df: pd.DataFrame, outlier_rate: float = 0.01) -> pd.DataFrame:
        """Introduce realistic outliers"""
        np.random.seed(101112)
        
        # Energy production outliers (equipment malfunctions or exceptional conditions)
        energy_outliers = np.random.random(len(df)) < outlier_rate
        outlier_multiplier = np.random.choice([0.1, 0.2, 2.0, 3.0], size=energy_outliers.sum())
        
        if energy_outliers.any():
            df.loc[energy_outliers, 'EnergyProduced_kWh'] *= outlier_multiplier
        
        return df
    
    def generate_site_data(self, site_id: str, weather_conditions: np.ndarray = None, 
                         temperature: np.ndarray = None, wind_speed: np.ndarray = None,
                         spot_prices: np.ndarray = None) -> pd.DataFrame:
        """Generate data for a single site"""
        logger.info(f"Generating data for site {site_id}")
        
        site_info = self.sites[site_id]
        
        # Use provided weather data or generate new (for consistency across sites)
        if weather_conditions is None or temperature is None or wind_speed is None:
            weather_conditions, temperature, wind_speed = self._generate_weather_data(self.date_range)
        
        # Use provided spot prices or generate new
        if spot_prices is None:
            spot_prices = self._generate_spot_market_price(self.date_range)
        
        # Generate energy production
        energy_production = self._generate_energy_production(
            site_id, site_info, self.date_range, weather_conditions, temperature, wind_speed
        )
        
        # Generate downtime
        downtime_hours = self._generate_downtime(self.date_range, site_info['type'])
        
        # Adjust production for downtime
        availability = 1 - (downtime_hours / 24)
        energy_production *= availability
        
        # Calculate revenue
        revenue = energy_production * spot_prices / 1000  # Convert kWh to MWh for pricing
        
        # Create DataFrame
        df = pd.DataFrame({
            'Date': self.date_range,
            'SiteID': site_id,
            'SiteName': site_info['name'],
            'SiteType': site_info['type'],
            'EnergyProduced_kWh': energy_production,
            'SpotMarketPrice': spot_prices,
            'Revenue': revenue,
            'WeatherCondition': weather_conditions,
            'DowntimeHours': downtime_hours,
            'Temperature_C': temperature,
            'WindSpeed_mps': wind_speed
        })
        
        return df
    
    def generate_all_data(self) -> pd.DataFrame:
        """Generate data for all sites"""
        logger.info("Starting data generation for all sites")
        
        # Generate shared weather and price data (same for all sites on each date)
        logger.info("Generating shared weather and market data")
        weather_conditions, temperature, wind_speed = self._generate_weather_data(self.date_range)
        spot_prices = self._generate_spot_market_price(self.date_range)
        
        all_data = []
        
        for site_id in self.sites.keys():
            site_data = self.generate_site_data(
                site_id, weather_conditions, temperature, wind_speed, spot_prices
            )
            all_data.append(site_data)
        
        # Combine all site data
        combined_data = pd.concat(all_data, ignore_index=True)
        
        # Introduce missing values and outliers
        combined_data = self._introduce_missing_values(combined_data)
        combined_data = self._introduce_outliers(combined_data)
        
        # Recalculate revenue after missing values/outliers (to handle NaN energy properly)
        combined_data['Revenue'] = combined_data['EnergyProduced_kWh'] * combined_data['SpotMarketPrice'] / 1000
        
        # Sort by date and site
        combined_data = combined_data.sort_values(['Date', 'SiteID']).reset_index(drop=True)
        
        logger.info(f"Generated {len(combined_data)} records for {len(self.sites)} sites")
        
        return combined_data
    
    def save_data(self, df: pd.DataFrame, output_dir: str = "output") -> str:
        """Save generated data to CSV file"""
        os.makedirs(output_dir, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"abc_renewables_synthetic_data_{timestamp}.csv"
        filepath = os.path.join(output_dir, filename)
        
        df.to_csv(filepath, index=False)
        logger.info(f"Data saved to {filepath}")
        
        return filepath
    
    def generate_summary_stats(self, df: pd.DataFrame) -> Dict:
        """Generate summary statistics for the dataset"""
        stats = {
            'total_records': len(df),
            'date_range': {
                'start': df['Date'].min().strftime('%Y-%m-%d'),
                'end': df['Date'].max().strftime('%Y-%m-%d')
            },
            'sites': {
                'total_sites': df['SiteID'].nunique(),
                'site_types': df['SiteType'].value_counts().to_dict(),
                'sites_list': df['SiteID'].unique().tolist()
            },
            'energy_production': {
                'total_kwh': df['EnergyProduced_kWh'].sum(),
                'avg_daily_kwh': df['EnergyProduced_kWh'].mean(),
                'max_daily_kwh': df['EnergyProduced_kWh'].max()
            },
            'revenue': {
                'total_revenue': df['Revenue'].sum(),
                'avg_daily_revenue': df['Revenue'].mean(),
                'max_daily_revenue': df['Revenue'].max()
            },
            'data_quality': {
                'missing_values': df.isnull().sum().to_dict(),
                'missing_percentage': (df.isnull().sum() / len(df) * 100).to_dict()
            }
        }
        
        return stats


def main():
    """Main execution function"""
    print("🌞⚡🔋 ABC Renewables Synthetic Data Generator")
    print("=" * 50)
    
    # Initialize generator
    generator = RenewableEnergyDataGenerator(
        start_date="2022-01-01",
        end_date="2024-12-31"
    )
    
    # Generate data
    print("Generating synthetic data...")
    data = generator.generate_all_data()
    
    # Save data
    print("Saving data to file...")
    filepath = generator.save_data(data)
    
    # Generate and save summary statistics
    print("Generating summary statistics...")
    stats = generator.generate_summary_stats(data)
    
    stats_file = filepath.replace('.csv', '_summary.json')
    with open(stats_file, 'w') as f:
        json.dump(stats, f, indent=2, default=str)
    
    # Display preview and summary
    print("\n📊 Data Generation Summary:")
    print(f"✅ Generated {stats['total_records']:,} records")
    print(f"✅ Date range: {stats['date_range']['start']} to {stats['date_range']['end']}")
    print(f"✅ Sites: {stats['sites']['total_sites']} ({stats['sites']['site_types']})")
    print(f"✅ Total energy: {stats['energy_production']['total_kwh']:,.0f} kWh")
    print(f"✅ Total revenue: ${stats['revenue']['total_revenue']:,.2f}")
    print(f"✅ Missing values: {sum(stats['data_quality']['missing_values'].values())} ({sum(stats['data_quality']['missing_percentage'].values()):.2f}%)")
    
    print(f"\n📁 Files saved:")
    print(f"   📄 Data: {filepath}")
    print(f"   📊 Summary: {stats_file}")
    
    print("\n🔍 Sample data preview:")
    print(data.head(10).to_string(index=False))
    
    print("\n🚀 Azure Data Lake Upload Instructions:")
    print("To upload this data to Azure Data Lake Storage:")
    print("1. Use Azure Storage Explorer or Azure CLI")
    print("2. Upload to container: 'raw'")
    print("3. Folder structure: raw/renewable_energy/YYYY/MM/")
    print("4. Or use the Azure Python SDK with your .env credentials")
    
    return data, stats


if __name__ == "__main__":
    try:
        data, stats = main()
        print("\n✅ Data generation completed successfully!")
    except Exception as e:
        logger.error(f"Error during data generation: {str(e)}")
        sys.exit(1) 