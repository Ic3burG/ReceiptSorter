# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🚀 Phase 2 Progress (Native macOS App)
- **Native Notifications**: Implemented system-level alerts using `UserNotifications`.
    - The app now requests notification permissions on first launch.
    - Sends success alerts when data extraction is complete.
    - Sends success alerts when a receipt is synced to Google Sheets.
- **Completed Sync Pipeline**: Wired up the "Sync to Sheets" button.
- **UI Polish & Architecture**: Settings Window, Live Preview, Visual Feedback.
- **Google Sheets Integration**: Implemented `SheetService` in Swift using JWT authentication.
- **Modern UI Update**: Bumped target to **macOS 13.0**.
- **Gemini Swift Integration**: Integrated the `GoogleGenerativeAI` Swift SDK.
- **Full macOS Pipeline**: End-to-end extraction.
- **Native SwiftUI App**: Implemented the `ReceiptSorterApp` target.
- **Swift CLI Tool**: Developed `receipt-cli`.
- **Native OCR**: Implemented `OCRService` using Vision.

### 🛠️ Fixes & Polish
- **Fixed Network Access**: Added entitlements to allow outgoing API calls in the sandboxed app.
- **Improved Error Handling**: Surfaced specific Gemini API errors to the UI.
- **Documentation**: Clarified Google Sheets setup instructions in README and App UIs.

### 🚀 Major Features Added (Phase 1)
- **User Onboarding**: Setup Wizard & One-Click Launcher.
- **Visual Feedback**: Loading spinners.
- **Batch Editing**: Review dashboard.
- **Settings UI**: Config page.
- **Docker Support**: Containerization.
- **Gemini & Web App**: Migrated to Gemini and FastAPI.

---