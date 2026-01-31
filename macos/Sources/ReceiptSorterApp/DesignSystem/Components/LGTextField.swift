import SwiftUI

public struct LGTextField: View {
    let title: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    public init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }
    
    public var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.plain)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(0.5))
                
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: isFocused ? [.blue.opacity(0.5), .cyan.opacity(0.5)] : [.white.opacity(0.2), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isFocused ? 1 : 0.5
                    )
            }
            .focused($isFocused)
            .animation(LiquidGlassAnimations.quickSpring, value: isFocused)
    }
}
