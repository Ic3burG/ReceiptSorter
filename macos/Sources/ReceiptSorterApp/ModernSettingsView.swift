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
    case cloudSync = "Cloud Sync"

    var id: String { rawValue }

    var icon: String {
      switch self {
      case .general: return "gear"
      case .export: return "square.and.arrow.up"
      case .organization: return "folder"
      case .cloudSync: return "icloud"
      }
    }

    var color: Color {
      switch self {
      case .general: return .gray
      case .export: return .blue
      case .organization: return .cyan
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
    case .cloudSync:
      CloudSyncSettingsDetailView()
    }
  }
}

// MARK: - General Settings Detail View

struct GeneralSettingsDetailView: View {
  @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
  @AppStorage("useLocalLLM") private var useLocalLLM: Bool = true
  @AppStorage("localModelId") private var localModelId: String =
    "mlx-community/Qwen2.5-3B-Instruct-4bit"
  @AppStorage("hfToken") private var hfToken: String = ""

  @EnvironmentObject var modelDownloadService: ModelDownloadService

  // Curated model options
  enum ModelOption: String, CaseIterable, Identifiable {
    case qwen3B = "mlx-community/Qwen2.5-3B-Instruct-4bit"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .qwen3B: return "Qwen 2.5 3B"
      case .custom: return "Custom Model"
      }
    }

    var description: String {
      switch self {
      case .qwen3B: return "Balanced • ~2GB • High quality"
      case .custom: return "Enter custom model ID"
      }
    }
  }

  @State private var selectedModel: ModelOption = .qwen3B
  @State private var customModelId: String = ""
  @State private var showCustomField: Bool = false

  var body: some View {
    Form {
      Section {
        Toggle("Use Local LLM", isOn: $useLocalLLM)
          .toggleStyle(.switch)
      } header: {
        Text("Artificial Intelligence")
      } footer: {
        if useLocalLLM {
          Text("Processing happens entirely on your device using MLX. No data leaves your Mac.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("Uses Gemini API for cloud-based processing.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if useLocalLLM {
        // Hugging Face Token Section
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

        // Model Selection Section
        Section {
          Picker("Model", selection: $selectedModel) {
            ForEach(ModelOption.allCases) { option in
              Text(option.displayName).tag(option)
            }
          }
          .onChange(of: selectedModel) { _, newValue in
            showCustomField = (newValue == .custom)
            if newValue != .custom {
              localModelId = newValue.rawValue
              downloadModelIfNeeded(modelId: localModelId)
            }
          }

          if showCustomField {
            LabeledContent("Custom Model ID") {
              HStack {
                TextField("e.g., mlx-community/Qwen2.5-1.5B-Instruct-4bit", text: $customModelId)
                  .textFieldStyle(.roundedBorder)

                Button("Use") {
                  if !customModelId.isEmpty {
                    localModelId = customModelId
                    downloadModelIfNeeded(modelId: localModelId)
                  }
                }
                .disabled(customModelId.isEmpty)
              }
            }
          }

          // Download Status
          if case .downloading(let progress) = modelDownloadService.state {
            LabeledContent("Download Progress") {
              HStack {
                ProgressView(value: progress)
                Text("\(Int(progress * 100))%")
                  .font(.caption)
                  .monospacedDigit()
              }
            }
          } else if modelDownloadService.isModelDownloaded(modelId: localModelId) {
            LabeledContent("Status") {
              Text("Ready")
                .foregroundStyle(.green)
            }
          } else {
            LabeledContent("Status") {
              Text("Not Downloaded")
                .foregroundStyle(.secondary)
            }
          }
        } header: {
          Text("Model Selection")
        }

      } else {
        // Gemini API Section
        Section {
          LabeledContent("API Key") {
            SecureField("Enter your Gemini API key", text: $geminiApiKey)
              .textFieldStyle(.roundedBorder)
          }
        } header: {
          Text("Gemini API")
        } footer: {
          Link(
            "Get an API key from Google AI Studio",
            destination: URL(string: "https://aistudio.google.com/")!
          )
          .font(.caption)
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("General")
    .onAppear {
      if let match = ModelOption.allCases.first(where: { $0.rawValue == localModelId }) {
        selectedModel = match
      } else {
        selectedModel = .custom
        customModelId = localModelId
        showCustomField = true
      }
    }
  }

  private func downloadModelIfNeeded(modelId: String) {
    Task {
      if !modelDownloadService.isModelDownloaded(modelId: modelId) && !hfToken.isEmpty {
        modelDownloadService.downloadModel(modelId: modelId)
      }
    }
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
