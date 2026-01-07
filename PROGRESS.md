# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🚀 Phase 2 Progress (Native macOS App)
- **UI Polish & Architecture**:
    - **Settings Window**: Implemented a native `SettingsView` (accessible via `Cmd+,`) to manage API keys and paths using `AppStorage`.
    - **Live Preview**: Added a split-view interface with `PDFKit` support, allowing users to see the receipt alongside the extracted data.
    - **Visual Feedback**: Integrated loading overlays and clear error states.
- **Google Sheets Integration**: Implemented `SheetService` in Swift using JWT authentication.
- **Modern UI Update**: Bumped target to **macOS 13.0** for modern SwiftUI features.
- **Gemini Swift Integration**: Integrated the `GoogleGenerativeAI` Swift SDK.
- **Full macOS Pipeline**: End-to-end extraction (Drop -> OCR -> AI -> UI).
- **Native SwiftUI App**: Implemented the `ReceiptSorterApp` target.
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