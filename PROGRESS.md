# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🛠️ Fixes & Polish
- **Settings UI Fix**: Increased the default size of the macOS Settings window (500x450) and added vertical scrolling to the Sync tab. This ensures the Google Sheets setup guide is fully visible and accessible.
- **Fixed Network Access**: Added entitlements to allow outgoing API calls in the sandboxed app.
- **Improved Error Handling**: Surfaced specific Gemini API errors to the UI.
- **Documentation**: Clarified Google Sheets setup instructions in README and App UIs.

### 🚀 Phase 2 Progress (Native macOS App)
- **Native Notifications**: Implemented system-level alerts using `UserNotifications`.
- **Completed Sync Pipeline**: Wired up the "Sync to Sheets" button.
- **UI Polish & Architecture**: Settings Window, Live Preview, Visual Feedback.
- **Google Sheets Integration**: Implemented `SheetService`.
- **Modern UI Update**: Bumped target to **macOS 13.0**.
- **Gemini Swift Integration**: Integrated the `GoogleGenerativeAI`.
- **Full macOS Pipeline**: Drop -> OCR -> AI -> UI -> Sync.
- **Native SwiftUI App**: Implemented the `ReceiptSorterApp` target.
- **Swift CLI Tool**: Developed `receipt-cli`.
- **Native OCR**: Implemented `OCRService` using Vision.

### 🚀 Major Features Added (Phase 1)
- **User Onboarding**: Setup Wizard & One-Click Launcher.
- **Visual Feedback**: Loading spinners.
- **Batch Editing**: Review dashboard.
- **Settings UI**: Config page.
- **Docker Support**: Containerization.
- **Gemini & Web App**: Migrated to Gemini and FastAPI.

---
