# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🚀 Major Features Added
- **Phase 2 Implementation: Native OCR**: Implemented `OCRService` in Swift using Apple's **Vision Framework**.
    - Replaces Tesseract dependency for the macOS app.
    - Handles both Images (`.jpg`, `.png`) and PDFs (`.pdf`) natively.
    - Uses `VNRecognizeTextRequest` with `.accurate` recognition level.
- **Phase 2 Initiation: Native macOS App**: Started the transition to a native macOS implementation.
    - Created the `macos/` root directory.
    - Initialized the **`ReceiptSorterCore`** Swift package using SPM (Swift Package Manager).
- **User Onboarding**: Created a seamless "First Run" experience.
    - **Setup Wizard**: The web app now detects missing keys and redirects to a friendly `/setup` page.
    - **One-Click Launcher**: Added `start_app.command` for macOS.
- **Visual Feedback**: Added animated loading overlays to the web interface.
- **Batch Editing & Review**: Implemented a two-stage processing workflow.
- **Settings UI**: Implemented a new settings page (`/settings`).
- **Docker Support**: Added `Dockerfile` and `docker-compose.yml`.
- **Gemini Integration**: Migrated to **Google Gemini**.

### 📦 Dependencies (New)
- **Swift 6.0+**: Standard library for native development.
- **Vision Framework**: Native Apple OCR.
- **PDFKit**: Native PDF handling.

---