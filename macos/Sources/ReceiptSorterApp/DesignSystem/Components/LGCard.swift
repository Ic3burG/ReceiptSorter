import SwiftUI

public struct LGCard<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding()
            .glassSurface(intensity: .standard)
    }
}
