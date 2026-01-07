# Project Progress Log

**IMPORTANT:** This file must be updated with a summary of changes after every session or significant code modification. These updates must be committed and pushed to the GitHub repository immediately.

## Session: January 6, 2026

### 🚀 Phase 2 & 3 Success (Native macOS App)
- **Resolved Gemini 404 Issues**: Successfully debugged the model mapping issues by verifying authorized models via `debug_models.py`. Switched the macOS app to use **Gemini 2.0 Flash**, ensuring cutting-edge extraction performance.
- **Native Notifications Implementation**: Integrated `UserNotifications` to provide system-level feedback on processing and syncing success.
- **App Icon Integration**: Successfully designed and applied a custom blue-and-yellow Squircle icon to the native application.
- **Distribution Bundle**: Finalized `macos/scripts/bundle.sh`, which now produces a signed, ready-to-run `Receipt Sorter.app` with proper entitlements.

### 🛠️ Fixes & Polish
- **REST Migration**: Replaced the Gemini Swift SDK with direct REST API calls to fix persistent gRPC/Sandbox network issues.
- **Settings UI Fix**: Increased the default size of the macOS Settings window and added vertical scrolling to ensure all configuration steps are visible.
- **Fixed Network Access**: Added `com.apple.security.network.client` and temporarily disabled strict Sandboxing to ensure reliable API connectivity in ad-hoc builds.
- **Error Handling**: Implemented `LocalizedError` for the core engine to provide descriptive UI messages instead of technical codes.

### 🚀 Major Features Added (Phase 1)
- **User Onboarding**: Setup Wizard & One-Click Launcher.
- **Visual Feedback**: Loading spinners in the Web UI.
- **Batch Editing**: Review dashboard for Web users.
- **Gemini & Web App**: Full migration to Gemini AI and FastAPI backend.

---