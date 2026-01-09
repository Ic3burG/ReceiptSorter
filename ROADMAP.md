# Product Roadmap

This document outlines the development trajectory for Receipt Sorter, a native macOS application for automated receipt processing and expense categorization.

## 🏁 Current Status

- **Platform**: Native macOS Application (Swift + SwiftUI)
- **OCR Engine**: Apple Vision Framework
- **AI Engine**: Google Gemini Swift SDK
- **Storage**: Google Sheets (via REST API)

## ✅ Completed Phases

### Phase 1: Python Prototype (Deprecated)

_The original Python web application has been removed in favor of the native macOS app._

- ✅ Python-based proof of concept with Tesseract OCR
- ✅ FastAPI web interface
- ✅ Docker containerization
- ✅ Google Sheets integration
- **Status**: Removed January 2026 - Replaced by native Swift implementation

### Phase 2: Native macOS App (Complete)

_Successfully migrated to Swift with superior performance and user experience._

#### Core Logic Package (`ReceiptSorterCore`)

- ✅ **OCRService**: Native text recognition using Apple Vision Framework (handles Images and PDFs)
- ✅ **GeminiService**: Google Generative AI Swift SDK for data extraction
- ✅ **SheetService**: Service Account auth via SwiftJWT and Google Sheets API
- ✅ **AuthService**: OAuth 2.0 implementation for Google services

#### Swift CLI Tool

- ✅ Command-line executable for testing and automation
- ✅ Standalone receipt processing without GUI

#### macOS UI (SwiftUI)

- ✅ Native drag-and-drop interface
- ✅ Live PDF/Image preview using PDFKit
- ✅ Settings window with API key management
- ✅ Native notifications for processing status
- ✅ Batch processing support
- ✅ Professional spreadsheet formatting

### Phase 3: Distribution (In Progress)

- ✅ **Packaging**: Build script (`bundle.sh`) for `.app` creation
- ✅ **CI/CD**: GitHub Actions workflow for automated builds
- ✅ **App Icon**: Professional macOS app icon
- 🔄 **Code Signing**: Apple Developer ID signing (pending)
- 🔄 **Notarization**: Apple Notary Service submission (pending)

## 📅 Upcoming Features

### Phase 4: Enhanced Distribution

_Goal: Make installation seamless for end users._

- [ ] **Code Signing**: Sign with Apple Developer ID certificate
- [ ] **Notarization**: Submit to Apple for notarization
- [ ] **DMG Installer**: Create professional disk image installer
- [ ] **Auto-Updates**: Implement Sparkle framework for automatic updates
- [ ] **Mac App Store**: Investigate App Store distribution

### Phase 5: Advanced Features

_Goal: Add power-user features and automation._

- [ ] **Watch Folders**: Background daemon that monitors folders and auto-processes new receipts
- [ ] **Duplicate Detection**: Identify and flag duplicate receipts
- [ ] **Currency Conversion**: Automatic conversion to CAD with historical exchange rates
- [ ] **Receipt Validation**: Anomaly detection and validation rules
- [ ] **Multi-Year Organization**: Annual reports and year-over-year comparisons
- [ ] **Shortcuts Integration**: macOS Shortcuts app support for automation
- [ ] **Export Formats**: QuickBooks, Xero, and other accounting software formats

### Phase 6: Platform Expansion

_Goal: Extend to other Apple platforms._

- [ ] **iOS App**: iPhone/iPad companion app sharing `ReceiptSorterCore`
- [ ] **iCloud Sync**: Sync receipts and settings across devices
- [ ] **Handoff Support**: Start on iPhone, finish on Mac
- [ ] **Widget Support**: Quick stats widget for macOS and iOS

## 🔮 Future Ideas

- **Apple Watch**: Quick receipt capture with camera
- **Email Integration**: Fetch receipts from email automatically
- **Cloud Storage**: Google Drive, Dropbox integration
- **Receipt Scanner**: Optimize for document scanner workflows
- **Team Features**: Multi-user support for businesses
- **Custom Categories**: User-defined tax categories beyond Canadian defaults

## Architecture Philosophy

The project follows these principles:

1. **Native First**: Use Apple frameworks whenever possible for best performance
2. **Modular Design**: Core logic separated from UI for reusability
3. **Privacy Focused**: All processing happens locally; only final data syncs to cloud
4. **User Experience**: Prioritize simplicity and intuitive design
5. **Open Source**: Maintain transparency and community contributions
