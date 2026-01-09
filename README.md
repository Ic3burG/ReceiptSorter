# Receipt Sorter - macOS App

[![macOS Build](https://github.com/ojdavis/ReceiptSorter/workflows/macOS%20App%20Build/badge.svg)](https://github.com/ojdavis/ReceiptSorter/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A native macOS application that automatically processes PDF receipts, extracts financial data, categorizes expenses for Canadian tax purposes, handles multiple currencies, and syncs everything to Google Sheets.

## Features

- 🖱️ **Native macOS Interface**: Beautiful SwiftUI interface with drag-and-drop support
- 📄 **Document Processing**: Extracts text from native PDFs and images (JPG, PNG, etc.) using Apple Vision Framework
- 🤖 **AI-Powered Extraction**: Uses Google Gemini AI to intelligently extract receipt data (amount, date, vendor, currency)
- 🏷️ **Smart Categorization**: Automatically categorizes receipts into Canadian tax deduction categories
- 💰 **Multi-Currency Support**: Handles CAD, USD, EUR, GBP, JPY, AUD, CHF
- ☁️ **Google Sheets Integration**: Automatically syncs receipt data to Google Sheets with professional formatting
- 🔔 **Native Notifications**: macOS notifications for processing status
- ⚡ **High Performance**: Native Swift implementation using Apple frameworks

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

### Requirements

- macOS 13.0 (Ventura) or later
- Google Gemini API key ([Get one here](https://aistudio.google.com/))
- Google Cloud Service Account (optional, for Google Sheets sync)

### Download

1. Download the latest release from the [Releases page](https://github.com/ojdavis/ReceiptSorter/releases)
2. Extract the `.zip` file
3. Move `Receipt Sorter.app` to your Applications folder
4. Double-click to launch

### First Launch Setup

1. **API Key Configuration**

   - Go to Settings (⌘,)
   - Enter your Google Gemini API key
   - The key is stored securely in your macOS Keychain

2. **Google Sheets Setup** (Optional)
   - Create a Service Account in [Google Cloud Console](https://console.cloud.google.com/)
   - Enable the Google Sheets API
   - Download the service account JSON credentials
   - In Receipt Sorter Settings, go to the Sync tab
   - Enter your Google Sheets ID and path to the credentials file
   - Click "Authenticate" to connect

## Usage

### Processing Receipts

1. Launch Receipt Sorter
2. Drag and drop receipt files (PDF, JPG, PNG) onto the drop zone
3. The app will automatically:
   - Extract text using Apple Vision OCR
   - Extract receipt data (vendor, date, amount, currency)
   - Categorize the expense
   - Display the results in the preview pane
4. Review the extracted data
5. Click "Sync to Sheets" to upload to Google Sheets

### Batch Processing

- Drop multiple files at once
- The app processes them sequentially
- Progress is shown in the status bar
- Notifications alert you when processing completes

### Google Sheets Format

Each receipt is added to your Google Sheet with:

| Date       | Vendor | Description     | Category        | Amount | Currency | File Name                   | Notes |
| ---------- | ------ | --------------- | --------------- | ------ | -------- | --------------------------- | ----- |
| 2024-01-15 | Amazon | Office supplies | Office Expenses | 45.99  | CAD      | 2024-01-15_Amazon_45.99.pdf |       |

The app also applies professional formatting:

- Blue header row with white bold text
- Frozen header row
- Currency formatting for amounts
- Auto-sized columns

## Building from Source

### Prerequisites

- Xcode 15.0 or later
- Swift 6.0 or later
- macOS 13.0 SDK

### Build Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/ojdavis/ReceiptSorter.git
   cd ReceiptSorter/macos
   ```

2. Build with Swift Package Manager:

   ```bash
   swift build -c release
   ```

3. Create the app bundle:

   ```bash
   ./scripts/bundle.sh
   ```

4. The app will be created at `Receipt Sorter.app`

### Running Tests

```bash
cd macos
swift test
```

## Project Structure

```
ReceiptSorter/
├── macos/                      # macOS Swift application
│   ├── Sources/
│   │   ├── ReceiptSorterCore/  # Core business logic
│   │   │   ├── OCRService.swift          # Apple Vision OCR
│   │   │   ├── GeminiService.swift       # AI data extraction
│   │   │   ├── SheetService.swift        # Google Sheets sync
│   │   │   └── AuthService.swift         # OAuth authentication
│   │   ├── ReceiptSorterApp/   # SwiftUI application
│   │   │   ├── ContentView.swift         # Main interface
│   │   │   ├── SettingsView.swift        # Settings window
│   │   │   └── PDFKitView.swift          # PDF preview
│   │   └── ReceiptCLI/         # Command-line tool
│   ├── Tests/                  # Test suite
│   ├── Resources/              # App resources
│   ├── scripts/                # Build scripts
│   └── Package.swift           # Swift package manifest
├── LICENSE
├── README.md
├── ROADMAP.md
└── PROGRESS.md
```

## Troubleshooting

### "Receipt Sorter.app" is damaged and can't be opened

This is a Gatekeeper warning for unsigned apps. To bypass:

```bash
xattr -cr "/Applications/Receipt Sorter.app"
```

### OCR not extracting text

- Ensure the image/PDF quality is good enough
- Try with a different file to verify OCR is working
- Check Console.app for Vision framework errors

### Google Sheets sync not working

- Verify your service account JSON is valid
- Ensure the Google Sheets API is enabled in your Google Cloud project
- Check that the sheet ID is correct
- Verify the service account email has Editor permissions on the sheet

### API errors

- Verify your Gemini API key is correct in Settings
- Check your API quota at [Google AI Studio](https://aistudio.google.com/)
- Ensure you have internet connectivity

## API Costs

This app uses the Google Gemini API for intelligent extraction and categorization. Each receipt requires approximately:

- 1 API call for data extraction
- 1 API call for categorization

Gemini 1.5 Flash is highly cost-effective and often has a generous free tier for developers.

## Future Enhancements

- [ ] Code signing and notarization for easier installation
- [ ] Duplicate receipt detection
- [ ] Currency conversion to CAD with exchange rates
- [ ] Export to accounting software formats (QuickBooks, Xero)
- [ ] Watch folders for automatic processing
- [ ] iOS companion app
- [ ] Shortcuts integration

## License

This project is provided as-is for personal and commercial use under the MIT License.

## Support

For issues or questions:

1. Check the Troubleshooting section above
2. Open an issue on [GitHub](https://github.com/ojdavis/ReceiptSorter/issues)
3. Check the macOS Console.app for detailed error logs

## Acknowledgments

- Built with [Google Gemini](https://aistudio.google.com/)
- OCR powered by Apple Vision Framework
- UI built with SwiftUI
