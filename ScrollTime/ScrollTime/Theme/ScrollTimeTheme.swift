import SwiftUI

// MARK: - ScrollTime Design System
// A Claude-inspired aesthetic: warm, minimal, thoughtful

/// Core color palette inspired by Claude's branding
struct STColors {
    // Primary brand color - Claude's warm terracotta
    static let primary = Color(hex: "E07A3D")
    static let primaryDark = Color(hex: "C96A32")
    static let primaryLight = Color(hex: "FEF3EC")

    // Backgrounds - warm, not cold
    static let background = Color(hex: "FAF8F5")
    static let surface = Color.white
    static let surfaceElevated = Color.white

    // Text hierarchy
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "6B6B6B")
    static let textTertiary = Color(hex: "9B9B9B")

    // Semantic colors
    static let success = Color(hex: "4A9B6E")
    static let warning = Color(hex: "E07A3D")
    static let subtle = Color(hex: "E8E4DF")
}

/// Typography using New York serif
struct STTypography {
    // Display - for hero moments
    static func displayLarge() -> Font {
        .system(size: 40, weight: .regular, design: .serif)
    }

    static func displayMedium() -> Font {
        .system(size: 32, weight: .regular, design: .serif)
    }

    // Titles
    static func titleLarge() -> Font {
        .system(size: 28, weight: .regular, design: .serif)
    }

    static func titleMedium() -> Font {
        .system(size: 22, weight: .medium, design: .serif)
    }

    static func titleSmall() -> Font {
        .system(size: 18, weight: .medium, design: .serif)
    }

    // Body text
    static func bodyLarge() -> Font {
        .system(size: 17, weight: .regular, design: .serif)
    }

    static func bodyMedium() -> Font {
        .system(size: 15, weight: .regular, design: .serif)
    }

    static func bodySmall() -> Font {
        .system(size: 13, weight: .regular, design: .serif)
    }

    // Labels and captions
    static func label() -> Font {
        .system(size: 12, weight: .medium, design: .default)
    }

    static func caption() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }
}

/// Spacing scale
struct STSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

/// Corner radius scale
struct STRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Custom View Components

/// Primary button style - warm and inviting
struct STPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(STTypography.bodyMedium())
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, STSpacing.lg)
            .padding(.vertical, STSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: STRadius.md)
                    .fill(STColors.primary)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary button style - subtle and refined
struct STSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(STTypography.bodyMedium())
            .fontWeight(.medium)
            .foregroundColor(STColors.primary)
            .padding(.horizontal, STSpacing.lg)
            .padding(.vertical, STSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: STRadius.md)
                    .fill(STColors.primaryLight)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Ghost button style - minimal
struct STGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(STTypography.bodyMedium())
            .foregroundColor(STColors.textSecondary)
            .padding(.horizontal, STSpacing.md)
            .padding(.vertical, STSpacing.sm)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Card container with subtle elevation
struct STCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: STRadius.lg)
                    .fill(STColors.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
    }
}

/// Divider with proper styling
struct STDivider: View {
    var body: some View {
        Rectangle()
            .fill(STColors.subtle)
            .frame(height: 1)
    }
}

// MARK: - View Extensions

extension View {
    func stBackground() -> some View {
        self.background(STColors.background.ignoresSafeArea())
    }
}
