import SwiftUI

public struct LGDataCard: View {
    let title: String
    let icon: String
    let value: String?
    
    public init(title: String, icon: String, value: String?) {
        self.title = title
        self.icon = icon
        self.value = value
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LiquidGlassTypography.caption)
                    .foregroundColor(.secondary)
                
                Text(value ?? "Unknown")
                    .font(LiquidGlassTypography.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.3))
            
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.1), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }
}
