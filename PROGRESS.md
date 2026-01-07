# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🚀 Phase 2 Progress (Native macOS App)
- **Google Sheets Integration**: Implemented `SheetService` in Swift.
    - Uses **JWT** (via `SwiftJWT`) to sign Service Account authentication requests.
    - Directly calls the Google Sheets API to append rows.
- **Modern UI Update**: Bumped target to **macOS 13.0 (Ventura)** to utilize `Grid` and `GridRow` for a cleaner data layout.
- **Gemini Swift Integration**: Integrated the `GoogleGenerativeAI` Swift SDK.
    - Created `GeminiService.swift` as a thread-safe `actor`.
- **Full macOS Pipeline**: The app now performs a complete end-to-end extraction:
    1.  **File Drop**: Accept PDF/Images via native Drag & Drop.
    2.  **Vision OCR**: Native text recognition.
    3.  **Gemini AI**: Intelligent data extraction from OCR text.
- **Native SwiftUI App**: Implemented the `ReceiptSorterApp` target.
    - **UI Enhancements**: Added Secure API Key input and structured data display.
- **Swift CLI Tool**: Developed `receipt-cli` for testing.
- **Native OCR**: Implemented `OCRService` using Apple's Vision Framework.

### 🚀 Major Features Added (Phase 1)
- **User Onboarding**: Setup Wizard & One-Click Launcher.
- **Visual Feedback**: Loading spinners.
- **Batch Editing**: Review dashboard.
- **Settings UI**: Config page.
- **Docker Support**: Containerization.
- **Gemini & Web App**: Migrated to Gemini and FastAPI.

### 📦 Dependencies (New)
- **SwiftJWT**: For signing Google Service Account requests.
- **Google Generative AI (Swift)**: For native AI capabilities.
- **SwiftUI, Vision, PDFKit**: Native Apple frameworks.

---
