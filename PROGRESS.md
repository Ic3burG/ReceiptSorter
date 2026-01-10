# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 10, 2026

### ✨ Welcome Screen & Onboarding Experience

- **New Welcome View**: Completely redesigned the empty state of the app with a polished first-run experience.
  - Added a welcoming header with gradient icon, "Welcome to Receipt Sorter" title, and descriptive subtitle.
  - Created `WelcomeView` and `SetupCard` SwiftUI components in `ContentView.swift`.
- **Quick Setup Cards**: Added inline configuration options directly on the welcome screen.
  - **API Key Setup**: Added a card to configure the Gemini API key directly from the onboarding flow.
  - **Spreadsheet Setup Card**: Shows current Excel file status with a "Choose File" button.
  - **Organization Folder Card**: Shows current folder status with a "Choose Folder" button.
  - **Quick Access**: Added "Reveal" buttons (magnifying glass) to instantly open the selected spreadsheet or folder.
  - Visual status indicators and a "X/3 configured" progress indicator.
- **Enhanced Drop Zone**: Redesigned the receipt drop area with:
  - Dashed border styling with animated hover states.
  - Helpful reminder text when setup is incomplete.
- **Cloud Sync Prompt**: Optional "Sign in for Cloud Sync" button for Google Sheets integration.

---

## Session: January 6, 2026

### 🚀 Major macOS Milestones

- **Batch Processing Dashboard**: Transformed the macOS app from a single-file viewer into a high-capacity processing engine.
  - Implemented a `NavigationSplitView` with a sidebar queue.
  - Added background queuing to process multiple receipts sequentially.
  - Created a "Sync All" workflow for bulk uploading extracted data.
- **Google OAuth 2.0 Integration**: Migrated to a user-friendly "Sign In with Google" flow.
  - Integrated `AppAuth-iOS` for standard browser-based authentication.
  - Implemented a dynamic Loopback HTTP listener to capture authentication tokens securely.
  - Added support for Client ID and Client Secret configuration via the UI.
- **Automated Spreadsheet Design**: Added a feature to programmatically "Format" Google Sheets.
  - Clicking "Apply Professional Formatting" in Settings now sets up blue headers, white bold text, frozen rows, and automatic currency formatting for the Amount column.
- **Smart Spreadsheet Link Parsing**: Enhanced the Settings UI to automatically extract the Spreadsheet ID from pasted full URLs, reducing configuration errors.

### 🛠️ CI/CD & Fixes

- **GitHub Actions Resolution**: Standardized the build environment on `macos-14` with `swift-tools-version: 5.10` to ensure a "Green" CI status.
- **Swift 6 Concurrency Fixes**: Resolved complex `Sendable` and `MainActor` isolation issues across `AuthService`, `SheetService`, and `ReceiptSorterCore`.
- **Network Entitlements**: Finalized the `.entitlements` configuration to allow the sandboxed app to communicate with Gemini and Google APIs.
- **App Icon**: Designed and integrated a native macOS icon into the production bundle.

---
