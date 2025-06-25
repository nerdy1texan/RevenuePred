#!/usr/bin/env python3
"""
Azure Data Lake Upload Script for ABC Renewables
==============================================

Uploads synthetic data to Azure Data Lake Storage Gen2 with proper
folder structure and metadata for the ML pipeline.
"""

import os
import sys
import pandas as pd
from datetime import datetime
import logging
from azure.storage.blob import BlobServiceClient, ContentSettings
from azure.identity import DefaultAzureCredential
from azure.core.exceptions import AzureError
import json
from typing import Optional
from pathlib import Path

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DataLakeUploader:
    """Upload data to Azure Data Lake Storage Gen2"""
    
    def __init__(self, storage_account_name: Optional[str] = None):
        """
        Initialize the Data Lake uploader
        
        Args:
            storage_account_name: Azure Storage account name (from env if not provided)
        """
        self.storage_account_name = storage_account_name or os.getenv('STORAGE_ACCOUNT_NAME', 'stabcrenewablesprod')
        self.container_name = 'raw'  # Raw data container
        
        # Try storage account key first, then fall back to Azure AD
        storage_key = os.getenv('AZURE_STORAGE_KEY')
        connection_string = os.getenv('AZURE_STORAGE_CONNECTION_STRING')
        
        try:
            if connection_string:
                # Use connection string if available
                self.blob_service_client = BlobServiceClient.from_connection_string(connection_string)
                logger.info(f"Initialized with connection string for storage account: {self.storage_account_name}")
            elif storage_key:
                # Use storage account key
                account_url = f"https://{self.storage_account_name}.blob.core.windows.net"
                self.blob_service_client = BlobServiceClient(
                    account_url=account_url,
                    credential=storage_key
                )
                logger.info(f"Initialized with storage key for storage account: {self.storage_account_name}")
            else:
                # Fall back to managed identity/Azure AD
                self.credential = DefaultAzureCredential()
                self.blob_service_client = BlobServiceClient(
                    account_url=f"https://{self.storage_account_name}.blob.core.windows.net",
                    credential=self.credential
                )
                logger.info(f"Initialized with Azure AD for storage account: {self.storage_account_name}")
        except Exception as e:
            logger.error(f"Failed to initialize Azure credentials: {str(e)}")
            logger.info("Make sure you have AZURE_STORAGE_KEY, AZURE_STORAGE_CONNECTION_STRING, or are authenticated with 'az login'")
            raise
    
    def create_folder_structure(self, date: datetime, data_type: str = "renewable_energy") -> str:
        """
        Create standardized folder structure for data lake
        
        Args:
            date: Date of the data
            data_type: Type of data (renewable_energy, weather, etc.)
        
        Returns:
            Folder path string
        """
        year = date.strftime('%Y')
        month = date.strftime('%m')
        day = date.strftime('%d')
        
        folder_path = f"{data_type}/{year}/{month}/{day}"
        return folder_path
    
    def upload_csv_data(self, csv_file_path: str, target_folder: str, 
                       filename: Optional[str] = None) -> str:
        """
        Upload CSV file to Data Lake
        
        Args:
            csv_file_path: Local path to CSV file
            target_folder: Target folder in Data Lake
            filename: Custom filename (uses original if not provided)
        
        Returns:
            Blob path of uploaded file
        """
        if not os.path.exists(csv_file_path):
            raise FileNotFoundError(f"CSV file not found: {csv_file_path}")
        
        # Determine filename
        if filename is None:
            filename = os.path.basename(csv_file_path)
        
        blob_path = f"{target_folder}/{filename}"
        
        try:
            # Get blob client
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_path
            )
            
            # Upload file
            logger.info(f"Uploading {csv_file_path} to {blob_path}")
            
            with open(csv_file_path, 'rb') as data:
                blob_client.upload_blob(
                    data,
                    overwrite=True,
                    metadata={
                        'source': 'synthetic_data_generator',
                        'upload_time': datetime.now().isoformat(),
                        'file_type': 'csv',
                        'data_category': 'renewable_energy'
                    }
                )
            
            logger.info(f"Successfully uploaded to: {blob_path}")
            return blob_path
            
        except AzureError as e:
            logger.error(f"Azure error during upload: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error during upload: {str(e)}")
            raise
    
    def upload_metadata(self, stats: dict, target_folder: str) -> str:
        """
        Upload metadata/statistics as JSON
        
        Args:
            stats: Statistics dictionary to upload
            target_folder: Target folder in Data Lake
        
        Returns:
            Blob path of uploaded metadata
        """
        metadata_blob_path = f"{target_folder}/metadata.json"
        
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=metadata_blob_path
            )
            
            # Convert stats to JSON string
            metadata_json = json.dumps(stats, indent=2, default=str)
            
            logger.info(f"Uploading metadata to {metadata_blob_path}")
            
            blob_client.upload_blob(
                metadata_json.encode('utf-8'),
                overwrite=True,
                content_settings=ContentSettings(content_type='application/json'),
                metadata={
                    'source': 'synthetic_data_generator',
                    'upload_time': datetime.now().isoformat(),
                    'file_type': 'metadata',
                    'data_category': 'renewable_energy'
                }
            )
            
            logger.info(f"Successfully uploaded metadata to: {metadata_blob_path}")
            return metadata_blob_path
            
        except AzureError as e:
            logger.error(f"Azure error during metadata upload: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error during metadata upload: {str(e)}")
            raise
    
    def list_blobs(self, folder_prefix: str = "") -> list:
        """
        List blobs in the container with optional prefix filter
        
        Args:
            folder_prefix: Prefix to filter blobs
        
        Returns:
            List of blob names
        """
        try:
            container_client = self.blob_service_client.get_container_client(self.container_name)
            blobs = container_client.list_blobs(name_starts_with=folder_prefix)
            
            blob_list = []
            for blob in blobs:
                blob_list.append({
                    'name': blob.name,
                    'size': blob.size,
                    'last_modified': blob.last_modified,
                    'content_type': blob.content_settings.content_type if blob.content_settings else None
                })
            
            return blob_list
            
        except AzureError as e:
            logger.error(f"Azure error during blob listing: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error during blob listing: {str(e)}")
            raise
    
    def verify_upload(self, blob_path: str) -> bool:
        """
        Verify that a blob was uploaded successfully
        
        Args:
            blob_path: Path to the blob to verify
        
        Returns:
            True if blob exists and is accessible
        """
        try:
            blob_client = self.blob_service_client.get_blob_client(
                container=self.container_name,
                blob=blob_path
            )
            
            # Get blob properties to verify it exists
            properties = blob_client.get_blob_properties()
            logger.info(f"Verified blob {blob_path}: {properties.size} bytes")
            return True
            
        except Exception as e:
            logger.error(f"Failed to verify blob {blob_path}: {str(e)}")
            return False


def upload_synthetic_data(csv_file_path: str, summary_file_path: Optional[str] = None) -> dict:
    """
    Upload synthetic data and metadata to Azure Data Lake
    
    Args:
        csv_file_path: Path to the CSV data file
        summary_file_path: Path to the summary JSON file (optional)
    
    Returns:
        Dictionary with upload results
    """
    logger.info("Starting upload to Azure Data Lake Storage")
    
    # Initialize uploader
    uploader = DataLakeUploader()
    
    # Read data to get date range for folder structure
    try:
        df = pd.read_csv(csv_file_path, parse_dates=['Date'], nrows=1)
        upload_date = df['Date'].iloc[0]
    except Exception as e:
        logger.warning(f"Could not read date from CSV, using current date: {str(e)}")
        upload_date = datetime.now()
    
    # Create folder structure
    target_folder = uploader.create_folder_structure(upload_date)
    logger.info(f"Target folder: {target_folder}")
    
    results = {
        'target_folder': target_folder,
        'uploaded_files': [],
        'errors': []
    }
    
    try:
        # Upload main CSV data
        csv_blob_path = uploader.upload_csv_data(csv_file_path, target_folder)
        results['uploaded_files'].append({
            'type': 'data',
            'local_path': csv_file_path,
            'blob_path': csv_blob_path,
            'verified': uploader.verify_upload(csv_blob_path)
        })
        
        # Upload summary metadata if provided
        if summary_file_path and os.path.exists(summary_file_path):
            with open(summary_file_path, 'r') as f:
                stats = json.load(f)
            
            metadata_blob_path = uploader.upload_metadata(stats, target_folder)
            results['uploaded_files'].append({
                'type': 'metadata',
                'local_path': summary_file_path,
                'blob_path': metadata_blob_path,
                'verified': uploader.verify_upload(metadata_blob_path)
            })
        
        logger.info("Upload completed successfully")
        
    except Exception as e:
        error_msg = f"Upload failed: {str(e)}"
        logger.error(error_msg)
        results['errors'].append(error_msg)
    
    return results


def main():
    """Main execution function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Upload synthetic data to Azure Data Lake')
    parser.add_argument('csv_file', help='Path to CSV data file')
    parser.add_argument('--summary', help='Path to summary JSON file (optional)')
    parser.add_argument('--storage-account', help='Azure Storage account name (optional)')
    
    args = parser.parse_args()
    
    print("🌊 Azure Data Lake Upload Tool")
    print("=" * 40)
    
    # Validate input file
    if not os.path.exists(args.csv_file):
        print(f"❌ Error: CSV file not found: {args.csv_file}")
        sys.exit(1)
    
    if args.summary and not os.path.exists(args.summary):
        print(f"❌ Error: Summary file not found: {args.summary}")
        sys.exit(1)
    
    try:
        # Perform upload
        results = upload_synthetic_data(args.csv_file, args.summary)
        
        # Display results
        print(f"\n📁 Target folder: {results['target_folder']}")
        print(f"📤 Uploaded files: {len(results['uploaded_files'])}")
        
        for file_info in results['uploaded_files']:
            status = "✅" if file_info['verified'] else "⚠️"
            print(f"   {status} {file_info['type']}: {file_info['blob_path']}")
        
        if results['errors']:
            print(f"\n❌ Errors: {len(results['errors'])}")
            for error in results['errors']:
                print(f"   • {error}")
            sys.exit(1)
        else:
            print("\n🎉 Upload completed successfully!")
            print("\n📋 Next steps:")
            print("   1. Verify data in Azure Storage Explorer")
            print("   2. Configure Data Factory to process this data")
            print("   3. Run data processing pipeline")
    
    except Exception as e:
        print(f"\n❌ Upload failed: {str(e)}")
        print("\n🔧 Troubleshooting:")
        print("   1. Ensure you're logged in: az login")
        print("   2. Check your .env file has correct storage account name")
        print("   3. Verify you have Storage Blob Data Contributor role")
        sys.exit(1)


if __name__ == "__main__":
    main() 