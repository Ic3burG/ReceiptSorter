import SwiftUI

public struct LGProcessingItemRow: View {
    let filename: String
    let subtitle: String
    let icon: String
    let color: Color
    
    @State private var isHovering = false
    
    public init(filename: String, subtitle: String, icon: String, color: Color) {
        self.filename = filename
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(filename)
                    .font(LiquidGlassTypography.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(subtitle)
                    .font(LiquidGlassTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.1))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
