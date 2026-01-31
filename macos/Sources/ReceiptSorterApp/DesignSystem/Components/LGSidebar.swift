import SwiftUI

public struct LGSidebarStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
    }
}

public extension View {
    func lgSidebarStyle() -> some View {
        modifier(LGSidebarStyle())
    }
}
