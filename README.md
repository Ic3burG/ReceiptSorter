# Receipt Sorter & Categorization App

[![Python CI](https://github.com/ojdavis/ReceiptSorter/workflows/Python%20CI/badge.svg)](https://github.com/ojdavis/ReceiptSorter/actions)
[![Docker Build](https://github.com/ojdavis/ReceiptSorter/workflows/Docker%20Build%20%26%20Push/badge.svg)](https://github.com/ojdavis/ReceiptSorter/actions)
[![macOS Build](https://github.com/ojdavis/ReceiptSorter/workflows/macOS%20App%20Build/badge.svg)](https://github.com/ojdavis/ReceiptSorter/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

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

### 🚀 Quick Start (macOS)

1. **Clone or Download** this repository.
2. Double-click **`start_app.command`**.
3. The script will automatically:
   - Create a virtual environment
   - Install all dependencies
   - Check for Tesseract OCR (and try to install it via Homebrew)
   - Launch the app and open your browser
4. Follow the **Setup Wizard** in your browser to enter your API keys.

### Manual Installation

### Prerequisites

- Python 3.9 or higher
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

### Step 4: Set Up API Key

1. Get your Google Gemini API key from https://aistudio.google.com/
2. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
3. Edit `.env` and add your `GEMINI_API_KEY`.

### Step 5: Configure Google Sheets (Optional)

To enable syncing to Google Sheets, you need to set up a **Service Account**.

1. **Create Service Account**:

   - Go to [Google Cloud Console](https://console.cloud.google.com/).
   - Create a new project (e.g., "Receipt Sorter").
   - Enable the **Google Sheets API**.
   - Go to **IAM & Admin > Service Accounts** and create a new service account.
   - Go to the **Keys** tab, click **Add Key > Create new key**, and select **JSON**.
   - A file will download. Rename it to `service_account.json` and move it to this project's folder.

2. **Get Spreadsheet ID**:

   - Open your Google Sheet in a browser.
   - Look at the URL: `https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKb.../edit`
   - The long string between `/d/` and `/edit` is your **Spreadsheet ID**.

3. **Share the Sheet**:

   - Open `service_account.json` in a text editor and copy the `client_email` address.
   - Go to your Google Sheet, click **Share**, and paste that email address with **Editor** permissions.

4. **Update App Settings**:
   - **Web App**: Go to Settings and enter the ID.
   - **macOS App**: Go to App Menu > Settings > Sync and enter the ID and path.

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

| Date       | Vendor | Description     | Category        | Amount | Currency | File Name                   | Notes |
| ---------- | ------ | --------------- | --------------- | ------ | -------- | --------------------------- | ----- |
| 2024-01-15 | Amazon | Office supplies | Office Expenses | 45.99  | CAD      | 2024-01-15_Amazon_45.99.pdf |       |

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

````
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
### Testing

Create a test folder with sample receipts:

```bash
mkdir -p ~/receipts/source
# Add some PDF receipts
python main.py
````

Check the output in `~/receipts/sorted/`

### CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment:

- **Python CI**: Runs linting, type checking, and tests on every push and PR
- **Docker Build**: Builds and publishes Docker images to GitHub Container Registry
- **macOS Build**: Builds the native Swift macOS application
- **Release**: Automatically creates releases with all artifacts when version tags are pushed

#### Running Tests Locally

```bash
# Install development dependencies
pip install -r requirements-dev.txt

# Run tests with coverage
pytest

# Run linting
ruff check .
black --check .
mypy .

# Run security checks
bandit -r .
safety check
```

#### Pre-commit Hooks

Set up pre-commit hooks to automatically check code quality before commits:

```bash
# Install pre-commit
pip install pre-commit

# Install the git hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```

#### Creating a Release

1. Update version in `pyproject.toml`
2. Commit changes: `git commit -am "chore: bump version to X.Y.Z"`
3. Create and push tag: `git tag vX.Y.Z && git push origin vX.Y.Z`
4. GitHub Actions will automatically:
   - Build Python wheel package
   - Build and push Docker image
   - Build macOS app bundle
   - Create GitHub release with all artifacts

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
