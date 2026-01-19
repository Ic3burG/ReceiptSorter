import SwiftUI
import ReceiptSorterCore

@main
struct ReceiptSorterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        Settings {
            ModernSettingsView()
        }
    }
}
