import SwiftUI

public struct GlassSurfaceModifier: ViewModifier {
    public enum Intensity {
        case subtle, standard, prominent

        var blurRadius: CGFloat {
            switch self {
            case .subtle: return 20
            case .standard: return 30
            case .prominent: return 40
            }
        }

        var opacity: Double {
            switch self {
            case .subtle: return 0.6
            case .standard: return 0.7
            case .prominent: return 0.85
            }
        }
    }

    public let intensity: Intensity
    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(intensity.opacity)

                    // Gradient overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 4, x: 0, y: 2)
    }
}

public extension View {
    func glassSurface(intensity: GlassSurfaceModifier.Intensity = .standard) -> some View {
        modifier(GlassSurfaceModifier(intensity: intensity))
    }
}
