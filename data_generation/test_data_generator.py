#!/usr/bin/env python3
"""
Unit Tests for ABC Renewables Synthetic Data Generator
====================================================

Tests for data schema, quality, and generation logic.
"""

import unittest
import pandas as pd
import numpy as np
import os
import tempfile
import json
from datetime import datetime, timedelta
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from generate_synthetic_data import RenewableEnergyDataGenerator


class TestRenewableEnergyDataGenerator(unittest.TestCase):
    """Test cases for the synthetic data generator"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.generator = RenewableEnergyDataGenerator(
            start_date="2023-01-01",
            end_date="2023-01-31"  # Short period for faster tests
        )
        self.sample_data = self.generator.generate_all_data()
    
    def test_schema_validation(self):
        """Test that generated data has correct schema"""
        expected_columns = [
            'Date', 'SiteID', 'SiteName', 'SiteType', 'EnergyProduced_kWh',
            'SpotMarketPrice', 'Revenue', 'WeatherCondition', 'DowntimeHours',
            'Temperature_C', 'WindSpeed_mps'
        ]
        
        # Check all required columns are present
        for col in expected_columns:
            self.assertIn(col, self.sample_data.columns, f"Missing column: {col}")
        
        # Check no extra columns
        self.assertEqual(
            len(self.sample_data.columns), 
            len(expected_columns),
            "Unexpected number of columns"
        )
    
    def test_data_types(self):
        """Test that data types are correct"""
        # Date column
        self.assertTrue(
            pd.api.types.is_datetime64_any_dtype(self.sample_data['Date']),
            "Date column should be datetime type"
        )
        
        # Numeric columns
        numeric_columns = [
            'EnergyProduced_kWh', 'SpotMarketPrice', 'Revenue',
            'DowntimeHours', 'Temperature_C', 'WindSpeed_mps'
        ]
        
        for col in numeric_columns:
            self.assertTrue(
                pd.api.types.is_numeric_dtype(self.sample_data[col]),
                f"{col} should be numeric type"
            )
        
        # String columns
        string_columns = ['SiteID', 'SiteName', 'SiteType', 'WeatherCondition']
        
        for col in string_columns:
            self.assertTrue(
                pd.api.types.is_object_dtype(self.sample_data[col]),
                f"{col} should be object/string type"
            )
    
    def test_site_configuration(self):
        """Test that all expected sites are present"""
        expected_sites = ['SOLAR001', 'SOLAR002', 'SOLAR003', 'WIND001', 'WIND002', 'BATT001']
        actual_sites = self.sample_data['SiteID'].unique()
        
        for site in expected_sites:
            self.assertIn(site, actual_sites, f"Missing site: {site}")
        
        # Check site types
        site_types = self.sample_data['SiteType'].unique()
        expected_types = ['solar', 'wind', 'battery']
        
        for site_type in expected_types:
            self.assertIn(site_type, site_types, f"Missing site type: {site_type}")
    
    def test_date_range(self):
        """Test that date range is correct"""
        min_date = self.sample_data['Date'].min()
        max_date = self.sample_data['Date'].max()
        
        self.assertEqual(
            min_date.date(), 
            self.generator.start_date.date(),
            "Minimum date doesn't match start date"
        )
        
        self.assertEqual(
            max_date.date(),
            self.generator.end_date.date(),
            "Maximum date doesn't match end date"
        )
    
    def test_data_completeness(self):
        """Test that data exists for all sites and dates"""
        expected_records = len(self.generator.date_range) * len(self.generator.sites)
        actual_records = len(self.sample_data)
        
        self.assertEqual(
            actual_records,
            expected_records,
            f"Expected {expected_records} records, got {actual_records}"
        )
    
    def test_value_ranges(self):
        """Test that values are within realistic ranges"""
        # Energy production should be non-negative (excluding NaN values)
        energy_valid = (self.sample_data['EnergyProduced_kWh'] >= 0) | self.sample_data['EnergyProduced_kWh'].isna()
        self.assertTrue(
            energy_valid.all(),
            "Energy production should be non-negative"
        )
        
        # Spot market price should be reasonable (> 0, < 500 $/MWh)
        price_valid = (self.sample_data['SpotMarketPrice'] > 0) & (self.sample_data['SpotMarketPrice'] < 500)
        self.assertTrue(
            price_valid.all(),
            "Spot market prices should be between 0 and 500 $/MWh"
        )
        
        # Revenue should be non-negative (excluding NaN values)
        revenue_valid = (self.sample_data['Revenue'] >= 0) | self.sample_data['Revenue'].isna()
        self.assertTrue(
            revenue_valid.all(),
            "Revenue should be non-negative"
        )
        
        # Downtime should be between 0 and 24 hours
        downtime_valid = (self.sample_data['DowntimeHours'] >= 0) & (self.sample_data['DowntimeHours'] <= 24)
        self.assertTrue(
            downtime_valid.all(),
            "Downtime should be between 0 and 24 hours"
        )
        
        # Temperature should be reasonable (-40 to 60 Celsius)
        temp_valid = (self.sample_data['Temperature_C'] >= -40) & (self.sample_data['Temperature_C'] <= 60)
        temp_valid_with_nan = temp_valid | self.sample_data['Temperature_C'].isna()
        self.assertTrue(
            temp_valid_with_nan.all(),
            "Temperature should be between -40 and 60 Celsius"
        )
        
        # Wind speed should be non-negative and reasonable (< 100 m/s)
        wind_valid = (self.sample_data['WindSpeed_mps'] >= 0) & (self.sample_data['WindSpeed_mps'] < 100)
        wind_valid_with_nan = wind_valid | self.sample_data['WindSpeed_mps'].isna()
        self.assertTrue(
            wind_valid_with_nan.all(),
            "Wind speed should be between 0 and 100 m/s"
        )
    
    def test_weather_conditions(self):
        """Test that weather conditions are valid"""
        expected_weather = ['Sunny', 'Partly Cloudy', 'Cloudy', 'Rainy', 'Stormy', 'Foggy']
        actual_weather = self.sample_data['WeatherCondition'].unique()
        
        for weather in actual_weather:
            self.assertIn(weather, expected_weather, f"Invalid weather condition: {weather}")
    
    def test_missing_values(self):
        """Test that missing values are introduced appropriately"""
        # Check that some missing values exist (but not too many)
        missing_counts = self.sample_data.isnull().sum()
        total_records = len(self.sample_data)
        
        # Should have some missing values
        self.assertTrue(
            missing_counts.sum() > 0,
            "Should have some missing values"
        )
        
        # Missing values should be reasonable (< 10% per column)
        for col, missing_count in missing_counts.items():
            missing_pct = missing_count / total_records * 100
            self.assertLess(
                missing_pct, 10,
                f"Too many missing values in {col}: {missing_pct:.2f}%"
            )
    
    def test_site_specific_data(self):
        """Test site-specific data characteristics"""
        # Solar sites should have higher production in summer months (if data spans seasons)
        solar_data = self.sample_data[self.sample_data['SiteType'] == 'solar']
        self.assertTrue(len(solar_data) > 0, "Should have solar data")
        
        # Wind sites should have production related to wind speed
        wind_data = self.sample_data[self.sample_data['SiteType'] == 'wind']
        self.assertTrue(len(wind_data) > 0, "Should have wind data")
        
        # Battery sites should have different patterns
        battery_data = self.sample_data[self.sample_data['SiteType'] == 'battery']
        self.assertTrue(len(battery_data) > 0, "Should have battery data")
    
    def test_revenue_calculation(self):
        """Test that revenue is calculated correctly"""
        # Revenue should equal energy production * spot price / 1000 (for MWh conversion)
        calculated_revenue = self.sample_data['EnergyProduced_kWh'] * self.sample_data['SpotMarketPrice'] / 1000
        
        # Allow for small floating point differences, handling NaN values
        revenue_diff = np.abs(self.sample_data['Revenue'] - calculated_revenue)
        
        # Only check non-NaN values
        valid_mask = ~(self.sample_data['Revenue'].isna() | calculated_revenue.isna())
        
        self.assertTrue(
            (revenue_diff[valid_mask] < 0.01).all(),
            "Revenue calculation doesn't match expected formula"
        )
    
    def test_data_generation_reproducibility(self):
        """Test that data generation is reproducible"""
        # Generate data twice and compare
        generator1 = RenewableEnergyDataGenerator("2023-01-01", "2023-01-07")
        generator2 = RenewableEnergyDataGenerator("2023-01-01", "2023-01-07")
        
        data1 = generator1.generate_all_data()
        data2 = generator2.generate_all_data()
        
        # Should be identical (due to fixed random seeds)
        pd.testing.assert_frame_equal(
            data1.fillna(0),  # Fill NaN for comparison
            data2.fillna(0),
            "Data generation should be reproducible"
        )
    
    def test_save_functionality(self):
        """Test data saving functionality"""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Save data
            filepath = self.generator.save_data(self.sample_data, temp_dir)
            
            # Check file exists
            self.assertTrue(os.path.exists(filepath), "Saved file should exist")
            
            # Check file can be read back
            loaded_data = pd.read_csv(filepath, parse_dates=['Date'])
            
            # Compare with original (excluding potential precision differences)
            self.assertEqual(len(loaded_data), len(self.sample_data), "Loaded data should have same length")
            self.assertEqual(list(loaded_data.columns), list(self.sample_data.columns), "Loaded data should have same columns")
    
    def test_summary_stats(self):
        """Test summary statistics generation"""
        stats = self.generator.generate_summary_stats(self.sample_data)
        
        # Check required keys exist
        required_keys = ['total_records', 'date_range', 'sites', 'energy_production', 'revenue', 'data_quality']
        
        for key in required_keys:
            self.assertIn(key, stats, f"Missing key in stats: {key}")
        
        # Check some values
        self.assertEqual(stats['total_records'], len(self.sample_data))
        self.assertEqual(stats['sites']['total_sites'], len(self.generator.sites))
        self.assertGreater(stats['energy_production']['total_kwh'], 0)
        self.assertGreater(stats['revenue']['total_revenue'], 0)


class TestDataQuality(unittest.TestCase):
    """Test data quality aspects"""
    
    def setUp(self):
        """Set up test fixtures with longer time series"""
        self.generator = RenewableEnergyDataGenerator(
            start_date="2023-01-01",
            end_date="2023-12-31"
        )
        self.annual_data = self.generator.generate_all_data()
    
    def test_seasonal_patterns(self):
        """Test that seasonal patterns exist in the data"""
        # Group by month and site type
        monthly_stats = (self.annual_data
                        .assign(Month=self.annual_data['Date'].dt.month)
                        .groupby(['Month', 'SiteType'])['EnergyProduced_kWh']
                        .mean()
                        .reset_index())
        
        # Solar should have higher production in summer months
        solar_monthly = monthly_stats[monthly_stats['SiteType'] == 'solar']
        
        # Summer months (June, July, August) should have higher average production
        summer_avg = solar_monthly[solar_monthly['Month'].isin([6, 7, 8])]['EnergyProduced_kWh'].mean()
        winter_avg = solar_monthly[solar_monthly['Month'].isin([12, 1, 2])]['EnergyProduced_kWh'].mean()
        
        self.assertGreater(
            summer_avg, winter_avg,
            "Solar production should be higher in summer than winter"
        )
    
    def test_correlations(self):
        """Test expected correlations in the data"""
        # For solar sites, energy production should correlate with sunny weather
        solar_data = self.annual_data[self.annual_data['SiteType'] == 'solar'].copy()
        solar_data['is_sunny'] = (solar_data['WeatherCondition'] == 'Sunny').astype(int)
        
        if len(solar_data) > 10:  # Only test if we have enough data
            correlation = solar_data['EnergyProduced_kWh'].corr(solar_data['is_sunny'])
            self.assertGreater(correlation, 0, "Solar production should correlate positively with sunny weather")


def run_all_tests():
    """Run all tests and return results"""
    print("🧪 Running ABC Renewables Data Generator Tests")
    print("=" * 50)
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test cases
    suite.addTests(loader.loadTestsFromTestCase(TestRenewableEnergyDataGenerator))
    suite.addTests(loader.loadTestsFromTestCase(TestDataQuality))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 50)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    
    if result.failures:
        print("\nFailures:")
        for test, traceback in result.failures:
            print(f"  {test}: {traceback}")
    
    if result.errors:
        print("\nErrors:")
        for test, traceback in result.errors:
            print(f"  {test}: {traceback}")
    
    success = len(result.failures) == 0 and len(result.errors) == 0
    print(f"\n{'✅ All tests passed!' if success else '❌ Some tests failed!'}")
    
    return success


if __name__ == "__main__":
    success = run_all_tests()
    exit(0 if success else 1) 