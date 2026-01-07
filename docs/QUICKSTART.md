# Quick Start Guide

Get up and running with Receipt Sorter in 5 minutes!

## 1. Install Dependencies

### Python Packages
```bash
pip install -r requirements.txt
```

### Tesseract OCR

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

## 2. Configure API Key

```bash
# Copy the example file
cp .env.example .env

# Edit .env and add your API key
# Get your key from: https://console.anthropic.com/
```

Edit `.env`:
```
ANTHROPIC_API_KEY=sk-ant-your-actual-key-here
```

## 3. Test Setup (Optional but Recommended)

```bash
python test_setup.py
```

This will verify:
- All Python packages are installed
- Tesseract is configured correctly
- API key is valid
- API connection works

## 4. Prepare Receipts

Place your PDF receipts in the source folder:
```bash
mkdir -p ~/receipts/source
# Copy your PDF receipts to ~/receipts/source/
```

## 5. Run the Application

```bash
python main.py
```

That's it! The app will:
1. Extract data from each receipt
2. Categorize them automatically
3. Sort into currency folders
4. Create Excel spreadsheets

## 6. Review Results

Check the output folder:
```bash
ls ~/receipts/sorted/
```

You'll find:
- `CAD/` - Canadian dollar receipts + spreadsheet
- `USD/` - US dollar receipts + spreadsheet
- `Review_Required/` - Receipts needing manual review
- `processing_log.txt` - Detailed processing log

## Custom Folders

To use different folders:
```bash
python main.py --source /path/to/receipts --output /path/to/output
```

## Troubleshooting

### "ANTHROPIC_API_KEY not found"
- Make sure you created the `.env` file
- Check that the API key is correct
- Don't use quotes around the key in `.env`

### "No text extracted from PDF"
- Ensure Tesseract is installed: `tesseract --version`
- Check that the PDF isn't corrupted
- Try opening the PDF manually to verify it's readable

### OCR not working on Windows
Edit `config.py` and set the Tesseract path:
```python
TESSERACT_CMD = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
```

## Next Steps

- Review the generated Excel spreadsheets
- Check `Review_Required/` folder for flagged receipts
- Customize categories in `config.py`
- Read the full [README.md](README.md) for advanced features

## Need Help?

1. Run `python test_setup.py` to diagnose issues
2. Check `receipt_sorter.log` for detailed error messages
3. Review `processing_log.txt` for file operation details

## Video Tutorial

Coming soon! Check back later for a video walkthrough.
