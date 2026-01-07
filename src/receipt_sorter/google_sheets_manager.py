"""
Google Sheets Manager Module
Handles updating Google Sheets with receipt data
"""

import gspread
from google.oauth2.service_account import Credentials
import logging
from typing import Dict, List, Optional
import os
from . import config

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GoogleSheetsManager:
    """Manage Google Sheets for receipt tracking"""

    def __init__(self):
        """Initialize Google Sheets client"""
        self.sheet_id = config.GOOGLE_SHEET_ID
        self.credentials_file = config.GOOGLE_SERVICE_ACCOUNT_FILE
        self.client = self._authenticate()
        self.columns = config.SPREADSHEET_COLUMNS

    def _authenticate(self) -> Optional[gspread.Client]:
        """
        Authenticate with Google Sheets API

        Returns:
            gspread.Client if successful, None otherwise
        """
        if not self.sheet_id:
            logger.warning("GOOGLE_SHEET_ID not configured")
            return None

        if not os.path.exists(self.credentials_file):
            logger.warning(f"Google service account file not found: {self.credentials_file}")
            return None

        try:
            scopes = [
                'https://www.googleapis.com/auth/spreadsheets',
                'https://www.googleapis.com/auth/drive'
            ]
            credentials = Credentials.from_service_account_file(
                self.credentials_file,
                scopes=scopes
            )
            return gspread.authorize(credentials)
        except Exception as e:
            logger.error(f"Failed to authenticate with Google Sheets: {str(e)}")
            return None

    def add_receipt_entry(self, receipt_data: Dict, category: str,
                         confidence: int, organized_filepath: str) -> bool:
        """
        Add receipt entry to Google Sheet

        Args:
            receipt_data: Extracted receipt data
            category: Tax category
            confidence: Categorization confidence score
            organized_filepath: Path to organized PDF file

        Returns:
            True if successful, False otherwise
        """
        if not self.client:
            logger.error("Google Sheets client not authenticated")
            return False

        try:
            currency = receipt_data.get('currency', 'UNKNOWN').upper()
            
            # Open the spreadsheet
            spreadsheet = self.client.open_by_key(self.sheet_id)
            
            # Try to get or create worksheet for the currency
            try:
                worksheet = spreadsheet.worksheet(currency)
            except gspread.WorksheetNotFound:
                worksheet = spreadsheet.add_worksheet(title=currency, rows="100", cols="20")
                worksheet.append_row(self.columns)
                # Format header
                worksheet.format("A1:H1", {
                    "backgroundColor": {"red": 0.2, "green": 0.4, "blue": 0.6},
                    "textFormat": {"foregroundColor": {"red": 1.0, "green": 1.0, "blue": 1.0}, "bold": True}
                })

            # Prepare new row
            new_row = [
                receipt_data.get('date', 'UNKNOWN'),
                receipt_data.get('vendor', 'UNKNOWN'),
                receipt_data.get('description', ''),
                category,
                receipt_data.get('total_amount', 0),
                currency,
                os.path.basename(organized_filepath),
                f"Confidence: {confidence}%" if confidence < 100 else ""
            ]

            # Append the row
            worksheet.append_row(new_row)
            
            logger.info(f"Added entry to Google Sheet ({currency}): {receipt_data.get('vendor')} - {receipt_data.get('total_amount')}")
            return True

        except Exception as e:
            logger.error(f"Error adding receipt entry to Google Sheets: {str(e)}")
            return False
