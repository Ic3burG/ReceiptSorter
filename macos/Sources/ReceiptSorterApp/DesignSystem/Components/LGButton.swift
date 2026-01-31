import SwiftUI

public struct LGButtonStyle: ButtonStyle {
    public enum Style {
        case primary
        case secondary
        case icon
    }
    
    let style: Style
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering = false
    
    public init(style: Style = .secondary) {
        self.style = style
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, style == .icon ? 12 : 16)
            .padding(.vertical, style == .icon ? 12 : 10)
            .background {
                ZStack {
                    if style == .primary {
                        // Vibrant gradient fill
                        RoundedRectangle(cornerRadius: style == .icon ? 20 : 12)
                            .fill(LiquidGlassColors.accentBlue)
                            .opacity(configuration.isPressed ? 0.9 : 1.0)
                            .shadow(color: .blue.opacity(0.4), radius: isHovering ? 12 : 8)
                    } else {
                        // Glass background
                        RoundedRectangle(cornerRadius: style == .icon ? 20 : 12)
                            .fill(.ultraThinMaterial)
                            .opacity(isHovering ? 0.8 : 0.6)
                        
                        // Border
                        RoundedRectangle(cornerRadius: style == .icon ? 20 : 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isHovering ? 0.4 : 0.2),
                                        .white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : (isHovering ? 1.02 : 1.0))
            .animation(LiquidGlassAnimations.quickSpring, value: configuration.isPressed)
            .animation(LiquidGlassAnimations.standardSpring, value: isHovering)
            .onHover { hover in
                isHovering = hover
            }
            .shadow(color: style == .primary ? .clear : .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: isHovering ? 6 : 4, x: 0, y: 2)
    }
}

public struct LGButton: View {
    let title: String
    let icon: String?
    let style: LGButtonStyle.Style
    let action: () -> Void
    
    public init(_ title: String, icon: String? = nil, style: LGButtonStyle.Style = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(LiquidGlassTypography.headline)
                }
                if !title.isEmpty {
                    Text(title)
                        .font(LiquidGlassTypography.headline)
                }
            }
            .foregroundColor(style == .primary ? .white : .primary)
        }
        .buttonStyle(LGButtonStyle(style: style))
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
