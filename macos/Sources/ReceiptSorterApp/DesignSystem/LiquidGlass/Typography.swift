import SwiftUI

public struct LiquidGlassTypography {
    // Headings with subtle glow effect
    public static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    public static let title = Font.system(.title, design: .rounded).weight(.semibold)
    public static let headline = Font.system(.headline, design: .rounded).weight(.medium)

    // Body with optimized readability on glass
    public static let body = Font.system(.body, design: .default).weight(.regular)
    public static let caption = Font.system(.caption, design: .default).weight(.regular)

    // Monospaced for data
    public static let code = Font.system(.body, design: .monospaced).weight(.regular)
}
