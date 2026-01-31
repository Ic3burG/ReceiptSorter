import SwiftUI

public struct LiquidGlassShadow: ViewModifier {
    public enum Elevation {
        case low, medium, high
    }

    public let elevation: Elevation
    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        
        switch elevation {
        case .low:
            content
                .shadow(color: .black.opacity(isDark ? 0.2 : 0.05), radius: 2, x: 0, y: 1)
        case .medium:
            content
                .shadow(color: .black.opacity(isDark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
                .shadow(color: .black.opacity(isDark ? 0.2 : 0.05), radius: 4, x: 0, y: 2)
        case .high:
            content
                .shadow(color: .black.opacity(isDark ? 0.4 : 0.15), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(isDark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
        }
    }
}

public extension View {
    func glassShadow(elevation: LiquidGlassShadow.Elevation = .medium) -> some View {
        modifier(LiquidGlassShadow(elevation: elevation))
    }
}
