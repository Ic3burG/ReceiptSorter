import SwiftUI
import Foundation

public struct LiquidGlassColors {
    // Accent colors with glow variants
    public static let accentBlue = LinearGradient(
        colors: [Color(hex: "007AFF"), Color(hex: "5AC8FA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let accentGreen = LinearGradient(
        colors: [Color(hex: "34C759"), Color(hex: "30D158")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Glass tints for different states
    public static let glassLight = Color.white.opacity(0.08)
    public static let glassDark = Color.black.opacity(0.15)

    // Dynamic shadows
    public static let shadowLight = Color.black.opacity(0.08)
    public static let shadowDark = Color.black.opacity(0.25)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
