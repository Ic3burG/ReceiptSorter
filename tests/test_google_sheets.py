"""
Test script for Google Sheets connectivity
"""

import os
import sys
import logging
from dotenv import load_dotenv

# Add src directory to path
sys.path.append(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src'))

from receipt_sorter import config
from receipt_sorter.google_sheets_manager import GoogleSheetsManager

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_google_sheets():
    """Test Google Sheets connectivity"""
    print("=" * 60)
    print("   Google Sheets Connectivity Test")
    print("=" * 60)
    
    # Check config
    if not config.GOOGLE_SHEET_ID:
        print("\n❌ Error: GOOGLE_SHEET_ID not found in .env or config")
        return
    
    if not os.path.exists(config.GOOGLE_SERVICE_ACCOUNT_FILE):
        print(f"\n❌ Error: Service account file '{config.GOOGLE_SERVICE_ACCOUNT_FILE}' not found")
        print("Please place your Google service account JSON file in the project root.")
        return
    
    print(f"✓ Config found. Sheet ID: {config.GOOGLE_SHEET_ID}")
    print(f"✓ Service account file found: {config.GOOGLE_SERVICE_ACCOUNT_FILE}")
    
    print("\n⏳ Attempting to authenticate and connect...")
    
    try:
        manager = GoogleSheetsManager()
        if not manager.client:
            print("❌ Authentication failed. Check log for details.")
            return
            
        # Try to open the spreadsheet
        spreadsheet = manager.client.open_by_key(config.GOOGLE_SHEET_ID)
        print(f"✓ Successfully connected to spreadsheet: {spreadsheet.title}")
        
        # List worksheets
        worksheets = spreadsheet.worksheets()
        print(f"✓ Found {len(worksheets)} worksheet(s):")
        for ws in worksheets:
            print(f"   - {ws.title}")
            
        print("\n✅ Google Sheets integration is working correctly!")
        
    except Exception as e:
        print(f"\n❌ Error connecting to Google Sheets: {str(e)}")
        print("\nTroubleshooting tips:")
        print("1. Ensure you've shared the Google Sheet with your service account email")
        print("2. Verify the GOOGLE_SHEET_ID is correct (from the URL)")
        print("3. Ensure the Google Sheets API and Google Drive API are enabled in your Google Cloud Project")

if __name__ == "__main__":
    test_google_sheets()
