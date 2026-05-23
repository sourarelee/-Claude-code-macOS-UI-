import SwiftUI

enum Design {
    enum Color {
        static let accent = SwiftUI.Color(red: 0.33, green: 0.53, blue: 0.92)
        static let accentBg = SwiftUI.Color(red: 0.33, green: 0.53, blue: 0.92).opacity(0.08)
        static let accentBgStrong = accent.opacity(0.15)
        static let assistantBg = SwiftUI.Color(nsColor: .controlBackgroundColor)
        static let sidebarBg = SwiftUI.Color(nsColor: .controlBackgroundColor)
        static let chatBg = SwiftUI.Color(nsColor: .textBackgroundColor)
        static let codeBg = SwiftUI.Color.primary.opacity(0.04)
    }
    enum Spacing {
        static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 12
        static let lg: CGFloat = 16, xl: CGFloat = 24
    }
    enum Radius {
        static let sm: CGFloat = 6, md: CGFloat = 10, lg: CGFloat = 16, xl: CGFloat = 20
    }
    enum Font {
        static let caption = SwiftUI.Font.system(size: 11)
        static let captionBold = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13.5)
        static let heading = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let code = SwiftUI.Font.system(size: 12.5, weight: .regular, design: .monospaced)
    }
    enum Animation {
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}

extension View {
    func bubbleStyle(isUser: Bool) -> some View {
        padding(.horizontal, Design.Spacing.lg)
            .padding(.vertical, Design.Spacing.md)
            .background(isUser ? Design.Color.accent : Design.Color.assistantBg)
            .foregroundColor(isUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius.lg))
    }
}
