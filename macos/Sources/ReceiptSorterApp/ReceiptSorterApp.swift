import SwiftUI
import ReceiptSorterCore

@main
struct ReceiptSorterApp: App {
    @StateObject private var modelDownloadService = ModelDownloadService()
    @AppStorage("useLocalLLM") private var localLLMEnabled = false
    @AppStorage("hasCompletedModelDownload") private var hasCompletedDownload = false
    @AppStorage("localModelId") private var localModelId: String = "mlx-community/Llama-3.2-1B-Instruct-4bit"
    @AppStorage("hfToken") private var hfToken: String = ""
    
    init() {
        // Set Hugging Face token environment variable if available
        // This allows HubApi to authenticate automatically
        if let token = UserDefaults.standard.string(forKey: "hfToken"), !token.isEmpty {
            setenv("HF_TOKEN", token, 1)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelDownloadService)
                .onAppear {
                    Task {
                        await checkAndDownloadModel()
                    }
                }
        }
        
        Settings {
            ModernSettingsView()
                .environmentObject(modelDownloadService)
        }
    }
    
    private func checkAndDownloadModel() async {
        // Only trigger if local LLM is enabled and we haven't completed download yet
        // OR if the user switched models and we need to download the new one (handled by download service checks)
        guard localLLMEnabled else { return }
        
        // We check if it's already downloaded in the service
        // If not, we start the download
        if !modelDownloadService.isModelDownloaded(modelId: localModelId) && !hasCompletedDownload {
            modelDownloadService.downloadModel(modelId: localModelId)
        }
    }
}
