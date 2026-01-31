import SwiftUI

public struct LGGroupBox<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    
    public init(@ViewBuilder label: () -> Label, @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
    }
    
    public init(label: String, @ViewBuilder content: () -> Content) where Label == Text {
        self.label = Text(label).font(LiquidGlassTypography.headline)
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            label
                .foregroundStyle(.secondary)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .glassSurface(intensity: .subtle)
    }
}
