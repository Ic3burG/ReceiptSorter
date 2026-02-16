# Receipt Sorter - macOS App

[![macOS Build](https://github.com/Ic3burG/ReceiptSorter/actions/workflows/ci-macos.yml/badge.svg)](https://github.com/Ic3burG/ReceiptSorter/actions/workflows/ci-macos.yml)
[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)

A privacy-first, native macOS application that automatically processes receipts, extracts financial data, and organizes your expenses—**all on your device**.

## 🔒 Privacy First

Receipt Sorter is designed with your privacy as the top priority.

- **100% Local Processing**: By default, all OCR and AI analysis happens directly on your Mac. No receipt data is sent to the cloud.
- **On-Device AI**: Powered by Apple Silicon and MLX, we run state-of-the-art LLMs (like Llama 3) locally to understand your documents.
- **Your Data, Your Control**: You choose where your data goes. Keep it local in Excel, or opt-in to sync specifically with your own Google Sheets.

## Features

- 🖱️ **Native macOS Interface**: Beautiful SwiftUI interface with drag-and-drop support.
- ⚡ **Local Intelligence**:
  - **OCR**: Text extraction using Apple's Vision Framework.
  - **AI Extraction**: Runs localized LLMs (Llama 3 via MLX) to parse amounts, dates, and vendors without internet.
- 🏷️ **Smart Categorization**: Automatically categorizes expenses for Canadian and US tax purposes.
- 💰 **Multi-Currency Support**: Handles CAD, USD, EUR, GBP, JPY, AUD, CHF.
- 📂 **Auto-Organization**: Automatically sorts processed files into Year/Month folders.
- 📊 **Excel Export**: Primary export to local Excel files with duplicate detection.
- ☁️ **Optional Cloud Sync**: Sync to Google Sheets only if you choose to.
- 🤖 **Cloud AI Option**: Optional support for Google Gemini API for users who prefer cloud-based processing.

## System Requirements

- **macOS 14.0 (Sonoma)** or later
- **Apple Silicon (M1/M2/M3/M4)** required for Local AI
- **16GB RAM** recommended for optimal local model performance

## Tax Categories

The app intelligently selects tax categories based on the receipt's currency.

- Office Expenses
- Meals & Entertainment
- Travel
- Vehicle Expenses
- Professional Services
- Marketing & Advertising
- Utilities & Rent
- Insurance
- Education & Training
- Other

### US Categories (USD)

- Advertising
- Vehicle Expenses
- Commissions & Fees
- Contract Labor
- Insurance
- Interest
- Legal & Professional Services
- Office Expenses
- Rent & Lease
- Repairs & Maintenance
- Supplies
- Taxes & Licenses
- Travel
- Meals
- Utilities
- Other

## Installation

### Download

1. Download the latest release from the [Releases page](https://github.com/Ic3burG/ReceiptSorter/releases).
2. Move `Receipt Sorter.app` to your Applications folder.

### First Run (Local AI)

1. Launch the app.
2. Go to **Settings > General**.
3. Ensure **"Use Local LLM"** is enabled (Default).
4. The first time you process a receipt, the app will download the optimized model (~2GB). This happens once.

### Cloud AI Setup (Optional)

If you prefer to use Google's servers instead of your local hardware:

1. Go to **Settings > General**.
2. Toggle "Use Local LLM" **OFF**.
3. Enter your Google Gemini API key ([Get one here](https://aistudio.google.com/)).

## Usage

1. **Drop**: Drag PDF or Image receipts onto the window.
2. **Process**: The app extracts data instantly.
3. **Review**: Check the extracted Amount, Vendor, and Category.
4. **Export**: Click "Export to Excel" to save and organize the file.

## Architecture & Security

- **Core**: Swift + SwiftUI
- **ML Engine**: [MLX Swift](https://github.com/ml-explore/mlx-swift) for local LLM inference.
- **Vision**: Apple Vision Framework for OCR.
- **Sandboxing**: App runs within the macOS Sandbox (with user-selected file access permissions).

## Building from Source

```bash
git clone https://github.com/Ic3burG/ReceiptSorter.git
cd ReceiptSorter/macos
swift build -c release
./scripts/bundle.sh
```

## License

GNU Affero General Public License v3.0 or later.
Commercial licensing available through OJD Technical Solutions.
