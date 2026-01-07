"""
Configuration file for Receipt Sorter Application
Defines paths, supported currencies, tax categories, and spreadsheet structure
"""

import os

# Folder paths
SOURCE_FOLDER = os.path.join(os.path.expanduser("~"), "receipts", "source")
OUTPUT_BASE_FOLDER = os.path.join(os.path.expanduser("~"), "receipts", "sorted")

# Supported currencies (ISO 4217 codes)
SUPPORTED_CURRENCIES = ["CAD", "USD", "EUR", "GBP", "JPY", "AUD", "CHF"]

# Canadian tax categories
TAX_CATEGORIES = [
    "Office Expenses",
    "Meals & Entertainment",
    "Travel",
    "Vehicle Expenses",
    "Professional Services",
    "Marketing & Advertising",
    "Utilities & Rent",
    "Insurance",
    "Education & Training",
    "Other"
]

# Spreadsheet column headers
SPREADSHEET_COLUMNS = [
    "Date",
    "Vendor",
    "Description",
    "Category",
    "Amount",
    "Currency",
    "File Name",
    "Notes"
]

# Google Sheets Configuration
GOOGLE_SHEET_ID = os.getenv("GOOGLE_SHEET_ID")
GOOGLE_SERVICE_ACCOUNT_FILE = os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE", "service_account.json")

# Currency symbols mapping
CURRENCY_SYMBOLS = {
    "$": ["CAD", "USD", "AUD"],  # Ambiguous, needs context
    "€": "EUR",
    "£": "GBP",
    "¥": "JPY",
    "CHF": "CHF"
}

# Confidence threshold for automatic categorization (0-100)
CATEGORIZATION_CONFIDENCE_THRESHOLD = 70

# File naming pattern
FILE_NAME_PATTERN = "{date}_{vendor}_{amount}.pdf"

# Processing log file
LOG_FILE = os.path.join(OUTPUT_BASE_FOLDER, "processing_log.txt")

# Review required folder for uncertain categorizations
REVIEW_FOLDER = os.path.join(OUTPUT_BASE_FOLDER, "Review_Required")

# Tesseract configuration (if using OCR)
# Update this path based on your Tesseract installation
TESSERACT_CMD = None  # Will use system default, or set to specific path
# Example for Windows: r'C:\Program Files\Tesseract-OCR\tesseract.exe'
# Example for macOS: '/usr/local/bin/tesseract'
# Example for Linux: '/usr/bin/tesseract'
