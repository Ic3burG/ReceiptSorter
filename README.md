# Receipt Sorter & Categorization App

Automatically process PDF receipts, extract financial data, categorize expenses for Canadian tax purposes, handle multiple currencies, and organize everything into folders and spreadsheets.

## Features

- 🌐 **Local Web Interface**: Modern, easy-to-use web dashboard for uploading and viewing results
- 📄 **Document Processing**: Extracts text from native PDFs and images (JPG, PNG, etc.) using OCR
- 🤖 **AI-Powered Extraction**: Uses Google Gemini AI to intelligently extract receipt data (amount, date, vendor, currency)
- 🏷️ **Smart Categorization**: Automatically categorizes receipts into Canadian tax deduction categories
- 💰 **Multi-Currency Support**: Handles CAD, USD, EUR, GBP, JPY, AUD, CHF
- 📁 **Automatic Organization**: Sorts receipts into currency-specific folders with standardized naming
- 📊 **Excel Reporting**: Generates formatted spreadsheets with category totals and breakdowns
- ☁️ **Google Sheets Integration**: Automatically syncs receipt data to Google Sheets (one sheet per currency)
- ⚠️ **Quality Assurance**: Flags low-confidence categorizations for manual review

## Canadian Tax Categories

The app classifies receipts into these categories:

1. **Office Expenses** - Office supplies, software, equipment, subscriptions
2. **Meals & Entertainment** - Restaurant meals, client entertainment (50% deductible)
3. **Travel** - Airfare, hotels, accommodation, transportation
4. **Vehicle Expenses** - Fuel, car maintenance, parking, tolls
5. **Professional Services** - Legal fees, accounting, consulting
6. **Marketing & Advertising** - Advertising costs, promotional materials
7. **Utilities & Rent** - Office rent, electricity, internet, phone bills
8. **Insurance** - Business insurance premiums
9. **Education & Training** - Courses, seminars, professional development
10. **Other** - Miscellaneous expenses

## Installation

### Prerequisites

- Python 3.8 or higher
- Tesseract OCR (for scanned documents)
- Google Gemini API key
- Docker & Docker Compose (optional, for containerized setup)

### Step 1: Clone or Download

```bash
cd ReceiptSorter
```

### Step 2: Install Python Dependencies

```bash
pip install -r requirements.txt
```

### Step 3: Install Tesseract OCR

**macOS:**
```bash
brew install tesseract
```

**Ubuntu/Debian:**
```bash
sudo apt-get install tesseract-ocr
```

**Windows:**
Download from: https://github.com/UB-Mannheim/tesseract/wiki

After installation on Windows, update `config.py` with the path to tesseract.exe:
```python
TESSERACT_CMD = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
```

### Step 4: Set Up API Key and Google Sheets

1. Get your Google Gemini API key from https://aistudio.google.com/
2. **(Optional)** Set up Google Sheets:
   - Create a Google Cloud Project and enable Google Sheets and Google Drive APIs.
   - Create a Service Account, download the JSON key, and rename it to `service_account.json` in the project root.
   - Create a new Google Sheet and share it with your Service Account email.
   - Copy the Spreadsheet ID from the URL: `https://docs.google.com/spreadsheets/d/[ID_IS_HERE]/edit`
3. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
4. Edit `.env` and add your keys:
   ```
   GEMINI_API_KEY=your-actual-api-key-here
   GOOGLE_SHEET_ID=your-spreadsheet-id
   ```

### Step 5: Configure Paths (Optional)

Edit `config.py` to customize:
- Source folder for receipts
- Output folder for sorted receipts
- Supported currencies
- Tax categories
- Confidence threshold for manual review

## Usage

### Docker Usage (Easiest)

If you have Docker installed, you don't need to install Python or Tesseract locally:

1. Create your `.env` file with your API keys.
2. Run the container:
   ```bash
   docker-compose up --build
   ```
3. Access the web app at `http://localhost:8000`

### Web Application (Recommended)

1. Start the web server:
   ```bash
   python run_web.py
   ```
2. Open your browser to `http://127.0.0.1:8000`
3. Drag and drop your receipts to process them!

### CLI Usage

1. Place your PDF/Image receipts in the source folder (default: `~/receipts/source`)
2. Run the application:
   ```bash
   python run.py
   ```

### Custom Folders

Specify custom source and output folders:
```bash
python main.py --source /path/to/receipts --output /path/to/sorted
```

### What Happens

The app will:
1. ✅ Validate your setup and check for receipts
2. 📖 Extract text from each document (PDF or Image with OCR)
3. 🔍 Extract receipt data (vendor, date, amount, currency)
4. 🏷️ Categorize into tax categories
5. 📁 Move receipts to currency-specific folders
6. 📊 Update local Excel spreadsheets with extracted data
7. ☁️ Sync data to Google Sheets (if configured)
8. 📋 Generate processing summary

### Output Structure

```
sorted/
├── CAD/
│   ├── CAD_Receipts.xlsx
│   ├── 2024-01-15_Amazon_45.99.pdf
│   └── 2024-01-16_Starbucks_12.50.png
├── USD/
│   ├── USD_Receipts.xlsx
│   └── 2024-01-20_AWS_150.00.pdf
├── Review_Required/
│   └── 2024-01-18_UnknownVendor_25.00.jpg
└── processing_log.txt
```

## Excel & Google Sheets Format

Each currency gets its own spreadsheet with:

| Date | Vendor | Description | Category | Amount | Currency | File Name | Notes |
|------|--------|-------------|----------|--------|----------|-----------|-------|
| 2024-01-15 | Amazon | Office supplies | Office Expenses | 45.99 | CAD | 2024-01-15_Amazon_45.99.pdf | |

Plus:
- **Total row** with sum of all amounts
- **Category breakdown** section with totals per category
- **Professional formatting** with headers, currency symbols, and formulas

## Configuration

### Customize Tax Categories

Edit `config.py` to modify the `TAX_CATEGORIES` list:
```python
TAX_CATEGORIES = [
    "Your Custom Category",
    "Another Category",
    # ...
]
```

### Adjust Confidence Threshold

Change how sensitive the manual review flagging is:
```python
CATEGORIZATION_CONFIDENCE_THRESHOLD = 70  # 0-100
```

Lower values = fewer manual reviews, higher values = more manual reviews

### Add More Currencies

Update the `SUPPORTED_CURRENCIES` list:
```python
SUPPORTED_CURRENCIES = ["CAD", "USD", "EUR", "GBP", "JPY", "AUD", "CHF", "MXN"]
```

## Troubleshooting

### "No text extracted from PDF"
- The PDF might be scanned/image-based - ensure Tesseract is installed
- Try opening the PDF manually to verify it's not corrupted
- Check Tesseract path in `config.py` (Windows users)

### "GEMINI_API_KEY not found"
- Make sure you created the `.env` file or used the Settings UI
- Verify the API key is correct
- Alternatively, set environment variable: `export GEMINI_API_KEY='your-key'`

### OCR not working
- Verify Tesseract installation: `tesseract --version`
- On Windows, set `TESSERACT_CMD` in `config.py`
- Ensure PDF quality is good enough for OCR

### Categorization seems incorrect
- Check the `Review_Required` folder for flagged receipts
- You can manually adjust categories in the Excel files
- Consider adjusting the confidence threshold in `config.py`

## Development

### Project Structure

```
receipt-sorter/
├── src/receipt_sorter/     # Core application package
│   ├── web/                # FastAPI web interface & templates
│   ├── config.py           # Configuration
│   ├── pdf_processor.py    # Document extraction
│   ├── data_extractor.py   # Gemini extraction logic
│   ├── categorizer.py      # Gemini categorization logic
│   └── ...
├── tests/                  # Test suite
├── docs/                   # Additional documentation
├── pyproject.toml          # Package configuration
├── Dockerfile              # Docker configuration
├── run_web.py              # Web app entry point
└── run.py                  # CLI entry point
```

### Testing

Create a test folder with sample receipts:
```bash
mkdir -p ~/receipts/source
# Add some PDF receipts
python main.py
```

Check the output in `~/receipts/sorted/`

## API Costs

This app uses the Google Gemini API for intelligent extraction and categorization. Each receipt requires approximately:
- 1 API call for data extraction
- 1 API call for categorization

Gemini 1.5 Flash is highly cost-effective and often has a generous free tier for developers.

## Future Enhancements

- [ ] Web interface for easier review and editing
- [ ] Duplicate receipt detection
- [ ] Currency conversion to CAD with exchange rates
- [ ] Export to accounting software formats (QuickBooks, Xero)
- [ ] Email integration to fetch receipts automatically
- [ ] Cloud storage integration (Google Drive, Dropbox)
- [ ] Receipt validation rules and anomaly detection
- [ ] Multi-year organization and annual reports

## License

This project is provided as-is for personal and commercial use.

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review the logs in `receipt_sorter.log`
3. Check `processing_log.txt` for file operation details

## Acknowledgments

- Built with [Google Gemini](https://aistudio.google.com/)
- PDF processing powered by [pdfplumber](https://github.com/jsvine/pdfplumber)
- OCR powered by [Tesseract](https://github.com/tesseract-ocr/tesseract)
