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

import AppKit
@preconcurrency import QuickLookUI
import ReceiptSorterCore
@preconcurrency import SwiftUI
@preconcurrency import UniformTypeIdentifiers
import UserNotifications

// Wrapper to workaround NSItemProvider not being Sendable
struct UnsafeSendableWrapper<T>: @unchecked Sendable {
  let value: T
}

struct ProcessingItem: Identifiable, Equatable {
  let id = UUID()
  var url: URL  // Mutable to update after file organization
  var status: ItemStatus = .pending
  var data: ReceiptData?
  var error: String?
  var organized: Bool = false  // Track if file has been organized

  enum ItemStatus: Equatable {
    case pending
    case processing
    case extracted
    case syncing
    case done
    case error
  }
}

struct ContentView: View {
  // Persistent Settings
  @AppStorage("geminiApiKey") private var apiKey: String = ""
  @AppStorage("useLocalLLM") private var useLocalLLM: Bool = true
  @AppStorage("localModelId") private var localModelId: String =
    "mlx-community/Llama-3.2-3B-Instruct-4bit"
  @AppStorage("excelFilePath") private var excelFilePath: String = ""
  @AppStorage("googleSheetId") private var googleSheetId: String = ""
  @AppStorage("googleClientID") private var clientID: String = ""
  @AppStorage("googleClientSecret") private var clientSecret: String = ""
  @AppStorage("organizationBasePath") private var organizationBasePath: String = ""
  @AppStorage("autoOrganize") private var autoOrganize: Bool = true
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

  // State
  @State private var items: [ProcessingItem] = []
  @State private var selectedItemId: UUID?
  @State private var isBatchProcessing = false
  @State private var signInError: String?
  @State private var showSignInError = false

  // Core Logic State
  @State private var core: ReceiptSorterCore?
  @State private var isAuthorized = false

  // Duplicate Review State
  @State private var showDuplicateReview = false
  @State private var duplicateConflict: DuplicateConflict?
  @State private var existingMetadata: FileMetadata?
  @State private var newMetadata: FileMetadata?

  // Download Service
  @EnvironmentObject var modelDownloadService: ModelDownloadService

  var body: some View {
    VStack(spacing: 0) {
      // Model Download Banner
      if case .downloading = modelDownloadService.state {
        ModelDownloadBanner(downloadService: modelDownloadService)
      } else if case .failed = modelDownloadService.state {
        ModelDownloadBanner(downloadService: modelDownloadService)
      }

      NavigationSplitView {
        sidebarContent
      } detail: {
        detailContent
      }
      .navigationSplitViewColumnWidth(min: 250, ideal: 300)
      .background(Color(NSColor.controlBackgroundColor))
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: importFiles) {
            Image(systemName: "plus")
          }
          .help("Import Receipts")
        }

        ToolbarItem(placement: .automatic) {
          if !items.isEmpty {
            Button(action: {
              items.removeAll()
              selectedItemId = nil
            }) {
              Image(systemName: "trash")
            }
            .help("Clear All")
          }
        }
      }

      .onAppear { initializeCore() }
      .onChange(of: apiKey) { _, _ in initializeCore() }
      .onChange(of: useLocalLLM) { _, _ in initializeCore() }
      .onChange(of: localModelId) { _, _ in initializeCore() }
      .onChange(of: excelFilePath) { _, _ in initializeCore() }
      .onChange(of: clientID) { _, _ in initializeCore() }
      .onChange(of: clientSecret) { _, _ in initializeCore() }
      .onChange(of: googleSheetId) { _, _ in initializeCore() }
      .onChange(of: organizationBasePath) { _, _ in initializeCore() }

    }
    .frame(minWidth: 900, minHeight: 600)
    .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
      loadFiles(from: providers)
      return true
    }
    .onAppear { requestNotificationPermissions() }
    .alert("Sign In Error", isPresented: $showSignInError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(signInError ?? "Unknown error")
    }
    .sheet(isPresented: $showDuplicateReview) {
      if let conflict = duplicateConflict {
        DuplicateReviewView(
          conflict: conflict,
          existingMetadata: existingMetadata,
          newMetadata: newMetadata,
          onResolution: { resolution in
            handleDuplicateResolution(resolution, for: conflict)
          }
        )
      }
    }
    .sheet(
      isPresented: Binding(
        get: { !hasCompletedOnboarding },
        set: { _ in }
      )
    ) {
      OnboardingView(
        isPresented: Binding(
          get: { !hasCompletedOnboarding },
          set: { if !$0 { hasCompletedOnboarding = true } }
        )
      )
      .interactiveDismissDisabled()
    }
  }

  // MARK: - Subviews

  private var sidebarContent: some View {
    VStack {
      if items.isEmpty {
        WelcomeView(
          apiKey: $apiKey,
          useLocalLLM: $useLocalLLM,
          excelFilePath: $excelFilePath,
          organizationBasePath: $organizationBasePath,
          isAuthorized: isAuthorized,
          onSignIn: signIn
        )
      } else {
        List(selection: $selectedItemId) {
          ForEach(items) { item in
            NavigationLink(value: item.id) {
              ProcessingItemRow(
                filename: item.url.lastPathComponent,
                subtitle: item.data?.vendor ?? statusText(for: item),
                icon: icon(for: item),
                color: color(for: item)
              )
              .padding(.vertical, 4)
            }
          }
        }
        .listStyle(.sidebar)

        // Batch Actions
        GroupBox("Actions") {
          VStack(spacing: 12) {
            // Authentication Status
            HStack {
              if isAuthorized {
                Label("Signed In", systemImage: "checkmark.circle.fill")
                  .foregroundColor(.green)
                  .font(.caption)
                Spacer()
                Button("Sign Out") {
                  signOut()
                }
                .buttonStyle(.bordered)
              } else {
                Label("Not Signed In", systemImage: "circle")
                  .foregroundColor(.secondary)
                  .font(.caption)
                Spacer()
                Button("Sign In") {
                  signIn()
                }
                .buttonStyle(.borderedProminent)
              }
            }

            HStack {
              Text("\(items.count) files")
                .font(.caption)
                .foregroundColor(.secondary)
              Spacer()
              Button("Clear All") {
                items.removeAll()
                selectedItemId = nil
              }
              .buttonStyle(.plain)
              .foregroundColor(.red)
              .font(.caption)
            }

            if items.contains(where: { $0.status == .extracted }) {
              Divider()

              // Primary: Export to Excel
              Button {
                exportAllToExcel()
              } label: {
                Label("Export to Excel", systemImage: "doc.badge.arrow.up")
              }
              .buttonStyle(.borderedProminent)
              .disabled(excelFilePath.isEmpty)

              // Secondary: Sync to Google Sheets
              if isAuthorized {
                Button {
                  syncAll()
                } label: {
                  Label("Sync to Google Sheets", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
              }
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
      }
    }
  }

  private var detailContent: some View {
    Group {
      if let selectedId = selectedItemId,
        let index = items.firstIndex(where: { $0.id == selectedId })
      {
        let item = items[index]

        HSplitView {
          // Preview (Left)
          ZStack {
            Color(NSColor.controlBackgroundColor)
            if item.url.pathExtension.lowercased() == "pdf" {
              PDFKitRepresentedView(url: item.url)
            } else {
              AsyncImage(url: item.url) { image in
                image.resizable().aspectRatio(contentMode: .fit)
              } placeholder: {
                ProgressView()
              }
            }
          }
          .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

          // Data (Right)
          ZStack {
            // Background
            Color(NSColor.controlBackgroundColor)

            VStack(alignment: .leading, spacing: 0) {
              HStack {
                Text("Details")
                  .font(.headline)
                Spacer()

                // Action Buttons
                if item.status == .extracted {
                  Menu {
                    Button("Export to Excel") { exportSingleToExcel(index) }
                    if isAuthorized {
                      Divider()
                      Button("Sync to Google Sheets") { syncSingle(index) }
                    }
                  } label: {
                    Text("Export")
                  }
                  .menuStyle(.borderlessButton)
                } else if item.status == .error {
                  Button("Retry") {
                    // Reset status and try processing again
                    Task { await processItem(at: index) }
                  }
                  .buttonStyle(.borderedProminent)
                }
              }
              .padding()

              Divider().overlay(.white.opacity(0.1))

              ScrollView {
                VStack(alignment: .leading, spacing: 16) {  // Reduced spacing for cards
                  if let data = item.data {
                    // Extracted Data Cards
                    DataCard(title: "Vendor", icon: "building.2", value: data.vendor)
                    DataCard(title: "Date", icon: "calendar", value: data.date)
                    DataCard(
                      title: "Amount", icon: "dollarsign.circle",
                      value:
                        "\(String(format: "%.2f", data.total_amount ?? 0.0)) \(data.currency ?? "")"
                    )
                    DataCard(title: "Category", icon: "tag", value: data.category)
                    DataCard(title: "Description", icon: "text.alignleft", value: data.description)

                    if item.status == .done {
                      HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Synced")
                      }
                      .font(.body)
                      .foregroundColor(.green)
                      .padding()
                      .frame(maxWidth: .infinity)
                      .background(
                        RoundedRectangle(cornerRadius: 12)
                          .fill(Color.green.opacity(0.15))
                      )
                    }
                  }

                  // Error State
                  if let error = item.error {
                    VStack(alignment: .leading, spacing: 8) {
                      Label("Processing Failed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.headline)
                      Text(error)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(12)
                  }

                  if item.status == .processing || item.status == .pending {
                    VStack(spacing: 12) {
                      ProgressView()
                        .controlSize(.large)
                      Text(item.status == .processing ? "Analyzing..." : "Waiting...")
                        .font(.body)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 50)
                  }
                }
                .padding()
              }
            }
          }
          .frame(minWidth: 250, maxWidth: 400, maxHeight: .infinity)
        }
      } else {
        Text("Select a receipt to view details")
          .foregroundColor(.secondary)
      }
    }
  }

  // MARK: - Logic

  @MainActor
  private func initializeCore() {
    NSLog("ReceiptSorter: [CORE] initializeCore called, useLocalLLM=\(useLocalLLM)")

    let localService: LocalLLMService?
    if useLocalLLM {
      NSLog("ReceiptSorter: [CORE] Creating LocalLLMService...")
      localService = LocalLLMService(modelId: localModelId)
      NSLog("ReceiptSorter: [CORE] LocalLLMService created successfully")
    } else {
      localService = nil
    }

    self.core = ReceiptSorterCore(
      apiKey: apiKey,
      clientID: clientID,
      clientSecret: clientSecret,
      sheetID: googleSheetId,
      excelFilePath: excelFilePath,
      organizationBasePath: organizationBasePath,
      localLLMService: localService
    )
    NSLog("ReceiptSorter: [CORE] ReceiptSorterCore initialized")

    Task {
      if let auth = core?.authService {
        self.isAuthorized = auth.isAuthorized
      }
    }
  }

  private func signIn() {
    guard let core = core, let auth = core.authService else { return }
    Task { @MainActor in
      do {
        if let window = NSApp.windows.first {
          try await auth.signIn(presenting: window)
          self.isAuthorized = true
        }
      } catch {
        print("Sign In Failed: \(error)")
      }
    }
  }

  @MainActor
  private func signOut() {
    guard let core = core, let auth = core.authService else { return }
    auth.signOut()
    self.isAuthorized = false
  }

  /// Extract a file URL from an NSItemProvider in a nonisolated context so the
  /// non-Sendable `NSSecureCoding` result never crosses an isolation boundary.
  nonisolated private func fileURL(from provider: NSItemProvider) async -> URL? {
    guard
      let urlData = try? await provider.loadItem(
        forTypeIdentifier: "public.file-url", options: nil) as? Data,
      let url = URL(dataRepresentation: urlData, relativeTo: nil)
    else { return nil }
    return url
  }

  private func loadFiles(from providers: [NSItemProvider]) {
    // Workaround for NSItemProvider not being Sendable in strict concurrency checks
    let safeProviders = UnsafeSendableWrapper(value: providers)

    Task { @MainActor in
      for provider in safeProviders.value {
        if let url = await fileURL(from: provider) {
          // Essential for files dropped from outside or network volumes
          _ = url.startAccessingSecurityScopedResource()

          let newItem = ProcessingItem(url: url)
          items.append(newItem)
          if items.count == 1 { selectedItemId = newItem.id }
        }
      }
      processBatch()
    }
  }

  private func importFiles() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.pdf, .image]

    panel.begin { response in
      if response == .OK {
        let providers = panel.urls.compactMap { NSItemProvider(contentsOf: $0) }
        self.loadFiles(from: providers)
      }
    }
  }

  @MainActor
  private func processBatch() {
    guard !isBatchProcessing else { return }
    isBatchProcessing = true
    Task {
      // Process sequentially but avoid blocking
      while let index = items.firstIndex(where: { $0.status == .pending }) {
        await processItem(at: index)

        // Allow UI to breathe between files
        await Task.yield()
      }
      isBatchProcessing = false
      notify(title: "Batch Complete", body: "Finished processing receipts.")
    }
  }

  private func processItem(at index: Int) async {
    // Run on background thread to prevent UI hangs (especially during OCR/MLX load)
    await Task.detached(priority: .userInitiated) {
      let (item, useLocal, key) = await MainActor.run {
        (items[index], useLocalLLM, apiKey)
      }

      // Re-access security scoped resource if needed (dropping files often requires this)
      let accessGranted = item.url.startAccessingSecurityScopedResource()
      defer {
        if accessGranted {
          item.url.stopAccessingSecurityScopedResource()
        }
      }

      if !useLocal && key.isEmpty {
        await MainActor.run { items[index].error = "Missing API Key" }
        return
      }

      let core = await MainActor.run { self.core }
      guard let core = core else { return }

      await MainActor.run { items[index].status = .processing }

      do {
        NSLog("ReceiptSorter: Starting OCR for \(item.url.lastPathComponent)")
        let text = try await core.extractText(from: item.url)

        NSLog("ReceiptSorter: Starting LLM extraction...")
        let data = try await core.extractReceiptData(from: text)

        await MainActor.run {
          items[index].data = data
          items[index].status = .extracted
          NSLog("ReceiptSorter: Extraction complete for \(item.url.lastPathComponent)")
        }
      } catch {
        let errorMessage = error.localizedDescription
        await MainActor.run {
          items[index].error = errorMessage
          items[index].status = .error
          NSLog("ReceiptSorter: Extraction failed: \(errorMessage)")
        }
      }
    }.value
  }

  private func syncAll() {
    Task {
      let indices = await MainActor.run { items.indices.filter { items[$0].status == .extracted } }
      for index in indices {
        await syncItem(at: index)
      }
    }
  }

  private func syncSingle(_ index: Int) {
    Task { await syncItem(at: index) }
  }

  private func syncItem(at index: Int) async {
    let item = await MainActor.run { items[index] }
    guard let data = item.data else { return }

    let core = await MainActor.run { self.core }
    guard let core = core else { return }

    await MainActor.run { items[index].status = .syncing }
    do {
      try await core.uploadToSheets(data: data)
      await MainActor.run { items[index].status = .done }
    } catch {
      await MainActor.run {
        items[index].error = "Sync Failed: \(error.localizedDescription)"
        items[index].status = .error
      }
    }
  }

  // MARK: - Excel Export

  private func exportAllToExcel() {
    Task {
      let indices = await MainActor.run { items.indices.filter { items[$0].status == .extracted } }
      for index in indices {
        await exportItem(at: index)
      }
      await MainActor.run { notify(title: "Export Complete", body: "Receipts exported to Excel.") }
    }
  }

  private func exportSingleToExcel(_ index: Int) {
    Task { await exportItem(at: index) }
  }

  private func exportItem(at index: Int) async {
    let item = await MainActor.run { items[index] }
    guard let data = item.data else { return }

    let core = await MainActor.run { self.core }
    guard let core = core else { return }

    await MainActor.run { items[index].status = .syncing }
    do {
      try await core.exportToExcel(data: data)

      // Auto-organize file after successful export
      if await MainActor.run(body: { autoOrganize && !organizationBasePath.isEmpty }) {
        if let dateString = data.date, !dateString.isEmpty {
          await organizeFileWithConflictDetection(at: index, date: dateString)
        }
      }

      await MainActor.run { items[index].status = .done }
    } catch {
      await MainActor.run {
        items[index].error = "Export Failed: \(error.localizedDescription)"
        items[index].status = .error
      }
    }
  }

  // MARK: - File Organization with Conflict Detection

  private func organizeFileWithConflictDetection(at index: Int, date: String) async {
    let core = await MainActor.run { self.core }
    guard let core = core,
      let service = core.fileOrganizationService
    else { return }

    let fileURL = await MainActor.run { items[index].url }

    do {
      let result = try await service.organizeReceiptWithConflictDetection(fileURL, date: date)

      switch result {
      case .success(let newURL):
        await MainActor.run {
          items[index].url = newURL
          items[index].organized = true
        }

      case .conflict(let existingURL, let proposedURL):
        // Get metadata for both files
        let existingMeta = await service.getFileMetadata(existingURL)
        let newMeta = await service.getFileMetadata(fileURL)

        // Show duplicate review dialog
        await MainActor.run {
          self.duplicateConflict = DuplicateConflict(
            existingURL: existingURL,
            newFileURL: fileURL,
            proposedURL: proposedURL,
            itemIndex: index
          )
          self.existingMetadata = existingMeta
          self.newMetadata = newMeta
          self.showDuplicateReview = true
        }

      case .skipped(let reason):
        print("File organization skipped: \(reason)")
      }
    } catch {
      print("File organization failed: \(error.localizedDescription)")
    }
  }

  private func handleDuplicateResolution(
    _ resolution: ConflictResolution, for conflict: DuplicateConflict
  ) {
    guard let core = self.core,
      let service = core.fileOrganizationService
    else { return }

    let index = conflict.itemIndex

    Task {
      do {
        let newURL = try await service.resolveConflict(
          sourceURL: conflict.newFileURL,
          existingURL: conflict.existingURL,
          resolution: resolution
        )

        await MainActor.run {
          if let newURL = newURL {
            items[index].url = newURL
            items[index].organized = true
          }
          // Clear conflict state
          duplicateConflict = nil
          existingMetadata = nil
          newMetadata = nil
        }
      } catch {
        await MainActor.run {
          items[index].error = "Resolution failed: \(error.localizedDescription)"
        }
      }
    }
  }

  // MARK: - Helpers

  private func icon(for item: ProcessingItem) -> String {
    if item.organized && item.status == .done {
      return "folder.circle.fill"  // Show folder icon for organized files
    }
    switch item.status {
    case .pending: return "clock"
    case .processing: return "gear"
    case .extracted: return "checkmark.circle"
    case .syncing: return "arrow.triangle.2.circlepath"
    case .done: return "checkmark.circle.fill"
    case .error: return "exclamationmark.circle.fill"
    }
  }

  private func color(for item: ProcessingItem) -> Color {
    switch item.status {
    case .done: return .green
    case .extracted: return .blue
    case .error: return .red
    default: return .secondary
    }
  }

  private func statusText(for item: ProcessingItem) -> String {
    switch item.status {
    case .pending: return "Queued"
    case .processing: return "Processing..."
    case .extracted: return "Ready to Export"
    case .syncing: return "Exporting..."
    case .done: return item.organized ? "Organized" : "Exported"
    case .error: return "Failed"
    }
  }

  private func requestNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  private func notify(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }
}
// MARK: - Helper Views

/// A sidebar row displaying file processing status
struct ProcessingItemRow: View {
  let filename: String
  let subtitle: String
  let icon: String
  let color: Color

  @State private var isHovering = false

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(color.opacity(0.15))
          .frame(width: 32, height: 32)

        Image(systemName: icon)
          .foregroundColor(color)
          .font(.system(size: 14))
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(filename)
          .font(.body)
          .foregroundColor(.primary)
          .lineLimit(1)
          .truncationMode(.middle)

        Text(subtitle)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
    .background {
      if isHovering {
        RoundedRectangle(cornerRadius: 8)
          .fill(.white.opacity(0.1))
      }
    }
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovering = hovering
      }
    }
  }
}

/// A card displaying extracted receipt data
struct DataCard: View {
  let title: String
  let icon: String
  let value: String?

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      ZStack {
        Circle()
          .fill(.ultraThinMaterial)
          .frame(width: 36, height: 36)

        Image(systemName: icon)
          .foregroundColor(.secondary)
          .font(.system(size: 14))
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption)
          .foregroundColor(.secondary)

        Text(value ?? "Unknown")
          .font(.body)
          .foregroundColor(.primary)
          .textSelection(.enabled)
      }

      Spacer()
    }
    .padding(12)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(.ultraThinMaterial.opacity(0.3))

      RoundedRectangle(cornerRadius: 12)
        .stroke(
          LinearGradient(
            colors: [.white.opacity(0.1), .white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.5
        )
    }
  }
}
