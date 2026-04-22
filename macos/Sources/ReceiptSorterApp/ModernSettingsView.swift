/*
 * ReceiptSorter
 * Copyright (c) 2025 OJD Technical Solutions
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Commercial licensing is available for enterprises.
 * Please contact OJD Technical Solutions for details.
 */

import ReceiptSorterCore
import SwiftUI

struct ModernSettingsView: View {
  @SceneStorage("settingsSelection") private var selectedSection: SettingsSection = .general

  enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case export = "Export"
    case organization = "Organization"
    case corrections = "Corrections"
    case cloudSync = "Cloud Sync"

    var id: String { rawValue }

    var icon: String {
      switch self {
      case .general: return "gear"
      case .export: return "square.and.arrow.up"
      case .organization: return "folder"
      case .corrections: return "brain"
      case .cloudSync: return "icloud"
      }
    }

    var color: Color {
      switch self {
      case .general: return .gray
      case .export: return .blue
      case .organization: return .cyan
      case .corrections: return .purple
      case .cloudSync: return .blue
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      // Sidebar
      List(SettingsSection.allCases, selection: $selectedSection) { section in
        NavigationLink(value: section) {
          Label {
            Text(section.rawValue)
          } icon: {
            Image(systemName: section.icon)
              .foregroundStyle(section.color)
          }
        }
      }
      .navigationTitle("Settings")
      .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    } detail: {
      // Detail view
      settingsDetailView(for: selectedSection)
    }
    .frame(minWidth: 700, minHeight: 500)
  }

  @ViewBuilder
  private func settingsDetailView(for section: SettingsSection) -> some View {
    switch section {
    case .general:
      GeneralSettingsDetailView()
    case .export:
      ExportSettingsDetailView()
    case .organization:
      OrganizationSettingsDetailView()
    case .corrections:
      CorrectionsSettingsDetailView()
    case .cloudSync:
      CloudSyncSettingsDetailView()
    }
  }
}

// MARK: - General Settings Detail View

struct GeneralSettingsDetailView: View {
  @AppStorage("hfToken") private var hfToken: String = ""
  @EnvironmentObject var modelDownloadService: ModelDownloadService

  var body: some View {
    Form {
      Section {
        LabeledContent("Model") {
          VStack(alignment: .leading, spacing: 4) {
            Text(GemmaModel.displayName)
              .fontWeight(.medium)
            Text("~\(GemmaModel.sizeEstimateBytes / 1_000_000_000)GB · Runs entirely on your device")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        // Download status
        if case .downloading(let progress) = modelDownloadService.state {
          LabeledContent("Download Progress") {
            HStack {
              ProgressView(value: progress)
              Text("\(Int(progress * 100))%")
                .font(.caption)
                .monospacedDigit()
            }
          }
        } else if modelDownloadService.isModelDownloaded(modelId: GemmaModel.modelId) {
          LabeledContent("Status") {
            Label("Ready", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .font(.caption)
          }
        } else if case .failed(let message) = modelDownloadService.state {
          LabeledContent("Status") {
            Label(message, systemImage: "xmark.circle.fill")
              .foregroundStyle(.red)
              .font(.caption)
          }
        } else {
          LabeledContent("Status") {
            Label("Not downloaded", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
              .font(.caption)
          }
        }
      } header: {
        Text("Artificial Intelligence")
      } footer: {
        Text("Processing happens entirely on your device using MLX. No data leaves your Mac.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        LabeledContent {
          VStack(alignment: .leading) {
            SecureField("Enter your token", text: $hfToken)
              .textFieldStyle(.roundedBorder)
              .textContentType(.password)
              .onChange(of: hfToken) { _, newValue in
                if !newValue.isEmpty {
                  setenv("HF_TOKEN", newValue, 1)
                }
              }

            if !hfToken.isEmpty {
              Text("Token configured")
                .font(.caption)
                .foregroundStyle(.green)
            }
          }
        } label: {
          Text("Hugging Face Token")
        }
      } header: {
        Text("Authentication")
      } footer: {
        VStack(alignment: .leading, spacing: 4) {
          Text("Required for model downloads.")
          Link(
            "Get a free token from Hugging Face",
            destination: URL(string: "https://huggingface.co/settings/tokens")!
          )
          .font(.caption)
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("General")
  }
}

// MARK: - Export Settings Detail View

struct ExportSettingsDetailView: View {
  @AppStorage("excelFilePath") private var excelFilePath: String = ""
  @State private var showFilePicker = false

  var body: some View {
    Form {
      Section {
        LabeledContent("Excel File") {
          HStack {
            Text(excelFilePath.isEmpty ? "No file selected" : excelFilePath)
              .foregroundStyle(excelFilePath.isEmpty ? .secondary : .primary)
              .lineLimit(1)
              .truncationMode(.middle)

            Button("Choose...") {
              showFilePicker = true
            }
          }
        }
      } header: {
        Text("Destination")
      } footer: {
        Text("Select an existing Excel file to update, or a new location to create one.")
      }

      Section {
        LabeledContent("Duplicate Detection") {
          Text("Enabled")
            .foregroundStyle(.secondary)
        }

        LabeledContent("Columns") {
          Text("Date, Vendor, Description, Category, Amount, Currency, Notes")
            .foregroundStyle(.secondary)
            .font(.caption)
        }
      } header: {
        Text("Configuration")
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Export")
    .fileImporter(
      isPresented: $showFilePicker,
      allowedContentTypes: [.init(filenameExtension: "xlsx")!, .data],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          _ = url.startAccessingSecurityScopedResource()
          excelFilePath = url.path
        }
      case .failure(let error):
        print("File picker error: \(error)")
      }
    }
  }
}

// MARK: - Organization Settings Detail View

struct OrganizationSettingsDetailView: View {
  @AppStorage("organizationBasePath") private var organizationBasePath: String = ""
  @AppStorage("autoOrganize") private var autoOrganize: Bool = true
  @State private var showFolderPicker = false

  var body: some View {
    Form {
      Section {
        Toggle("Auto-organize after export", isOn: $autoOrganize)
      } header: {
        Text("Automation")
      } footer: {
        Text("Receipts are moved to year/month folders based on the extracted date.")
      }

      Section {
        LabeledContent("Base Folder") {
          HStack {
            Text(organizationBasePath.isEmpty ? "No folder selected" : organizationBasePath)
              .foregroundStyle(organizationBasePath.isEmpty ? .secondary : .primary)
              .lineLimit(1)
              .truncationMode(.middle)

            Button("Choose...") {
              showFolderPicker = true
            }
          }
        }
      } header: {
        Text("Location")
      }

      Section {
        LabeledContent("Structure") {
          Text("YYYY / mm - Month YYYY")
            .monospaced()
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Preview")
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Organization")
    .fileImporter(
      isPresented: $showFolderPicker,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          _ = url.startAccessingSecurityScopedResource()
          organizationBasePath = url.path
        }
      case .failure(let error):
        print("Folder picker error: \(error)")
      }
    }
  }
}

// MARK: - Cloud Sync Settings Detail View

struct CloudSyncSettingsDetailView: View {
  @AppStorage("googleSheetId") private var googleSheetId: String = ""
  @AppStorage("googleClientID") private var clientID: String = ""
  @AppStorage("googleClientSecret") private var clientSecret: String = ""

  @State private var sheetInput: String = ""
  @State private var isFormatting = false

  var body: some View {
    Form {
      Section {
        LabeledContent("Spreadsheet Link") {
          TextField("https://docs.google.com/...", text: $sheetInput)
            .textFieldStyle(.roundedBorder)
            .onChange(of: sheetInput) { _, newValue in
              extractSheetID(from: newValue)
            }
            .onAppear { sheetInput = googleSheetId }
        }

        if !googleSheetId.isEmpty && googleSheetId != sheetInput {
          LabeledContent("Sheet ID") {
            Text(googleSheetId)
              .font(.caption)
              .monospaced()
              .foregroundStyle(.secondary)
          }
        }
      } header: {
        Text("Google Sheets")
      }

      Section {
        LabeledContent("Client ID") {
          TextField("OAuth Client ID", text: $clientID)
            .textFieldStyle(.roundedBorder)
        }

        LabeledContent("Client Secret") {
          SecureField("OAuth Client Secret", text: $clientSecret)
            .textFieldStyle(.roundedBorder)
        }
      } header: {
        Text("Authentication")
      } footer: {
        Text("Create a 'Desktop App' OAuth 2.0 Client ID in Google Cloud Console.")
      }

      if !googleSheetId.isEmpty {
        Section {
          Button {
            formatSheet()
          } label: {
            HStack {
              if isFormatting {
                ProgressView()
                  .controlSize(.small)
              }
              Text(isFormatting ? "Formatting..." : "Apply Formatting")
            }
          }
          .disabled(isFormatting)
        } header: {
          Text("Actions")
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Cloud Sync")
  }

  @MainActor
  private func formatSheet() {
    guard !googleSheetId.isEmpty else { return }
    isFormatting = true

    let core = ReceiptSorterCore(clientID: clientID, sheetID: googleSheetId)

    Task {
      do {
        if let auth = core.authService {
          if !auth.isAuthorized {
            if let window = NSApp.windows.first {
              try await auth.signIn(presenting: window)
            }
          }
        }

        try await core.formatSheet()
        isFormatting = false
      } catch {
        print("Formatting failed: \(error)")
        isFormatting = false
      }
    }
  }

  private func extractSheetID(from input: String) {
    if input.contains("/d/") {
      let components = input.components(separatedBy: "/d/")
      if components.count > 1 {
        let idPart = components[1]
        if let idEndIndex = idPart.firstIndex(of: "/") {
          self.googleSheetId = String(idPart[..<idEndIndex])
        } else {
          self.googleSheetId = idPart
        }
        return
      }
    }

    if let queryIndex = input.firstIndex(of: "?") {
      self.googleSheetId = String(input[..<queryIndex])
    } else {
      self.googleSheetId = input
    }
  }
}

// MARK: - Corrections Settings Detail View

struct CorrectionsSettingsDetailView: View {
  @EnvironmentObject var correctionStore: CorrectionStore
  @State private var showClearConfirmation = false

  var body: some View {
    Form {
      if !correctionStore.rules.isEmpty {
        Section {
          ForEach(correctionStore.rules.sorted { $0.applyCount > $1.applyCount }) { rule in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 2) {
                Text(rule.field.capitalized)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("\"\(rule.original)\" → \"\(rule.corrected)\"")
                  .font(.body)
              }
              Spacer()
              Text("applied \(rule.applyCount)×")
                .font(.caption)
                .foregroundStyle(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())
              Button(role: .destructive) {
                correctionStore.deleteRule(id: rule.id)
              } label: {
                Image(systemName: "trash")
                  .foregroundStyle(.red)
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
          }
        } header: {
          Text("Rules (applied automatically)")
        } footer: {
          Text("Promoted from corrections seen 3 or more times. Applied to every extraction.")
            .font(.caption)
        }
      }

      if !correctionStore.corrections.isEmpty {
        Section {
          ForEach(correctionStore.corrections.sorted { $0.updatedAt > $1.updatedAt }) { c in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 2) {
                Text(c.field.capitalized)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("\"\(c.original)\" → \"\(c.corrected)\"")
                  .font(.body)
              }
              Spacer()
              if c.count > 1 {
                Text("×\(c.count)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Button(role: .destructive) {
                correctionStore.deleteCorrection(id: c.id)
              } label: {
                Image(systemName: "trash")
                  .foregroundStyle(.red)
              }
              .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
          }
        } header: {
          Text("Examples (injected into AI prompt)")
        } footer: {
          Text("The 5 most recent examples are shown to the AI before each extraction.")
            .font(.caption)
        }
      }

      if correctionStore.corrections.isEmpty && correctionStore.rules.isEmpty {
        Section {
          Text(
            "No corrections recorded yet. Click any extracted field in the main view to correct it."
          )
          .foregroundStyle(.secondary)
          .font(.body)
        }
      }

      if !correctionStore.corrections.isEmpty || !correctionStore.rules.isEmpty {
        Section {
          Button(role: .destructive) {
            showClearConfirmation = true
          } label: {
            Text("Clear All Corrections & Rules")
              .foregroundStyle(.red)
          }
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Corrections")
    .confirmationDialog(
      "Clear all corrections and rules?",
      isPresented: $showClearConfirmation,
      titleVisibility: .visible
    ) {
      Button("Clear All", role: .destructive) { correctionStore.clearAll() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This cannot be undone. The AI will no longer learn from past edits.")
    }
  }
}
