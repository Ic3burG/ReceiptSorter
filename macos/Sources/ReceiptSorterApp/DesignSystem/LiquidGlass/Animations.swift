import SwiftUI

public struct LiquidGlassAnimations {
    // Quick interactions
    public static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)

    // Standard UI transitions
    public static let standardSpring = Animation.spring(response: 0.5, dampingFraction: 0.75)

    // Smooth, luxurious transitions
    public static let smoothSpring = Animation.spring(response: 0.7, dampingFraction: 0.8)

    // Floating elements
    public static let floatingAnimation = Animation
        .easeInOut(duration: 2.0)
        .repeatForever(autoreverses: true)
}
