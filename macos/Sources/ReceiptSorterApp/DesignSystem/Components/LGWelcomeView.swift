import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ReceiptSorterCore

public struct LGWelcomeView: View {
    @Binding var apiKey: String
    @Binding var useLocalLLM: Bool
    @Binding var excelFilePath: String
    @Binding var organizationBasePath: String
    let isAuthorized: Bool
    let onSignIn: () -> Void
    
    @State private var showApiKeySheet = false
    @State private var isHoveringDropZone = false
    
    // Logic for panels
    private func openSpreadsheetPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an existing Excel spreadsheet"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                 DispatchQueue.main.async {
                     self.excelFilePath = url.path
                 }
            }
        }
    }
    
    private func createNewSpreadsheet() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        panel.nameFieldStringValue = "Receipts.xlsx"
        panel.message = "Create a new spreadsheet"
        panel.prompt = "Create"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    // Use ExcelService to create a template
                    let service = ExcelService(fileURL: url)
                    do {
                        try await service.createNewSheet(with: [])
                        await MainActor.run {
                             self.excelFilePath = url.path
                        }
                    } catch {
                        print("Failed to create spreadsheet: \(error)")
                    }
                }
            }
        }
    }
    
    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folder]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select base folder for organization"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                 DispatchQueue.main.async {
                     self.organizationBasePath = url.path
                 }
            }
        }
    }
    
    private var isFullyConfigured: Bool {
        (!apiKey.isEmpty || useLocalLLM) && !excelFilePath.isEmpty && !organizationBasePath.isEmpty
    }
    
    private var configuredCount: Int {
        var count = 0
        if !apiKey.isEmpty || useLocalLLM { count += 1 }
        if !excelFilePath.isEmpty { count += 1 }
        if !organizationBasePath.isEmpty { count += 1 }
        return count
    }
    
    public init(apiKey: Binding<String>, useLocalLLM: Binding<Bool>, excelFilePath: Binding<String>, organizationBasePath: Binding<String>, isAuthorized: Bool, onSignIn: @escaping () -> Void) {
        self._apiKey = apiKey
        self._useLocalLLM = useLocalLLM
        self._excelFilePath = excelFilePath
        self._organizationBasePath = organizationBasePath
        self.isAuthorized = isAuthorized
        self.onSignIn = onSignIn
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section with Glow Effect
                    headerSection
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    
                    // Setup Status Section
                    setupStatusSection
                        .padding(.horizontal, 24)
                    
                    Spacer(minLength: 20)
                }
            }
            // Drop Zone Footer
            VStack(spacing: 12) {
                Divider().overlay(.white.opacity(0.1))
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                        .foregroundColor(isHoveringDropZone ? .blue : .secondary.opacity(0.3))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isHoveringDropZone ? Color.blue.opacity(0.1) : Color.clear)
                        )
                    
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 28))
                            .foregroundColor(isHoveringDropZone ? .blue : .secondary)
                        
                        Text("Drop receipts here")
                            .font(LiquidGlassTypography.body)
                            .foregroundColor(isHoveringDropZone ? .blue : .secondary)
                        
                        if !isFullyConfigured {
                            Text("Complete setup above for best experience")
                                .font(LiquidGlassTypography.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(height: 100)
                .padding(.horizontal, 24)
                .animation(LiquidGlassAnimations.quickSpring, value: isHoveringDropZone)
                .onHover { hovering in
                    isHoveringDropZone = hovering
                }
            }
            .padding(.bottom, 24)
            .background(LiquidGlassColors.glassDark)
            
            // Optional: Google Sign In for cloud sync
            if !isAuthorized {
                VStack(spacing: 0) {
                    Divider().overlay(.white.opacity(0.1))
                    
                    Button(action: onSignIn) {
                        HStack {
                            Image(systemName: "cloud")
                            Text("Sign in for Cloud Sync")
                        }
                        .font(LiquidGlassTypography.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .background(.ultraThinMaterial)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiquidGlassColors.glassDark)
        .sheet(isPresented: $showApiKeySheet) {
            apiKeySheetContent
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon with Glow Effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .blur(radius: 20)
                
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 0)
            }
            
            VStack(spacing: 4) {
                Text("Welcome to Receipt Sorter")
                    .font(LiquidGlassTypography.largeTitle)
                    .foregroundColor(.primary)
                
                Text("Extract, organize, and export your receipts with AI")
                    .font(LiquidGlassTypography.title)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var setupStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Setup")
                    .font(LiquidGlassTypography.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(configuredCount)/3 configured")
                    .font(LiquidGlassTypography.caption)
                    .foregroundColor(isFullyConfigured ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isFullyConfigured ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    )
            }
            .padding(.horizontal, 4)
            
            apiKeyCard
            excelCard
            organizationCard
        }
    }
    
    private var apiKeyCard: some View {
        LGSetupCard(
            icon: useLocalLLM ? "cpu" : "key",
            title: useLocalLLM ? "Local AI (MLX)" : "Gemini API Key",
            subtitle: useLocalLLM ? "Running locally on device" : (apiKey.isEmpty ? "Required for extraction" : "Key configured"),
            isConfigured: useLocalLLM || !apiKey.isEmpty,
            actionLabel: useLocalLLM ? "Settings" : (apiKey.isEmpty ? "Set Key" : "Change"),
            action: { 
                showApiKeySheet = true
            }
        )
    }
    
    private var excelCard: some View {
        let reveal: (() -> Void)? = excelFilePath.isEmpty ? nil : {
            NSWorkspace.shared.open(URL(fileURLWithPath: excelFilePath))
        }
        
        let createNew: (() -> Void)? = excelFilePath.isEmpty ? { self.createNewSpreadsheet() } : nil
        
        return LGSetupCard(
            icon: "doc.badge.arrow.up",
            title: "Spreadsheet",
            subtitle: excelFilePath.isEmpty ? "No file selected - Create or Choose one" : URL(fileURLWithPath: excelFilePath).lastPathComponent,
            isConfigured: !excelFilePath.isEmpty,
            actionLabel: excelFilePath.isEmpty ? "Choose File" : "Change",
            action: openSpreadsheetPicker,
            revealAction: reveal,
            secondaryActionLabel: excelFilePath.isEmpty ? "Create New" : nil,
            secondaryAction: createNew
        )
    }
    
    private var organizationCard: some View {
        LGSetupCard(
            icon: "folder.badge.gearshape",
            title: "Organization Folder",
            subtitle: organizationBasePath.isEmpty ? "No folder selected" : URL(fileURLWithPath: organizationBasePath).lastPathComponent,
            isConfigured: !organizationBasePath.isEmpty,
            actionLabel: organizationBasePath.isEmpty ? "Choose Folder" : "Change",
            action: openFolderPicker,
            revealAction: organizationBasePath.isEmpty ? nil : {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: organizationBasePath)
            }
        )
    }
    
    private var apiKeySheetContent: some View {
        ZStack {
            LiquidGlassColors.glassDark.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("AI Configuration")
                    .font(LiquidGlassTypography.headline)
                
                Toggle("Use Local LLM (Privacy Focused)", isOn: $useLocalLLM)
                    .toggleStyle(.switch)
                    .font(LiquidGlassTypography.body)
                    .padding(.horizontal)
                
                if !useLocalLLM {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gemini API Key")
                            .font(LiquidGlassTypography.caption)
                            .foregroundColor(.secondary)
                        
                        LGTextField("Enter API Key", text: $apiKey, isSecure: true)
                            .frame(width: 300)
                        
                        Link("Get API Key", destination: URL(string: "https://aistudio.google.com/")!)
                            .font(LiquidGlassTypography.caption)
                    }
                } else {
                    Text("Local LLM enabled. Models will be downloaded on first use.")
                        .font(LiquidGlassTypography.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 300)
                }
                
                HStack {
                    Spacer()
                    LGButton("Done", style: .primary) {
                        showApiKeySheet = false
                    }
                }
                .frame(width: 300)
            }
            .padding(30)
        }
        .frame(width: 400, height: 350)
    }
}

// MARK: - Setup Card Component

struct LGSetupCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isConfigured: Bool
    let actionLabel: String
    let action: () -> Void
    var revealAction: (() -> Void)? = nil
    var secondaryActionLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil
    
    var body: some View {
        LGCard {
            HStack(spacing: 16) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(isConfigured ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isConfigured ? "checkmark.circle.fill" : icon)
                        .font(.system(size: 20))
                        .foregroundColor(isConfigured ? .green : .orange)
                        .shadow(color: isConfigured ? .green.opacity(0.3) : .orange.opacity(0.3), radius: 5)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(LiquidGlassTypography.body)
                            .foregroundColor(.primary)
                        
                        if let revealAction = revealAction {
                            Button(action: revealAction) {
                                Image(systemName: "magnifyingglass.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text(subtitle)
                        .font(LiquidGlassTypography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    if let secondaryLabel = secondaryActionLabel, let secondaryAction = secondaryAction {
                        LGButton(secondaryLabel) {
                            secondaryAction()
                        }
                    }
                    
                    LGButton(actionLabel, style: isConfigured ? .secondary : .primary) {
                        action()
                    }
                }
            }
        }
    }
}
