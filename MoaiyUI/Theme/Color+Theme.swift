import SwiftUI

// MARK: - Moaiy Color Theme
// Based on design-system.md specifications

extension Color {
    
    // MARK: - Primary Colors (Moai Stone)
    static let moaiStone = Color(hex: "4A5568")
    static let moaiDark = Color(hex: "2D3748")
    static let moaiLight = Color(hex: "718096")
    
    // MARK: - Accent Colors (Security Green)
    static let securityGreen = Color(hex: "48BB78")
    static let securityGreenDark = Color(hex: "38A169")
    static let securityGreenLight = Color(hex: "9AE6B4")
    
    // MARK: - Semantic Colors
    static let moaiSuccess = Color(hex: "48BB78")
    static let moaiWarning = Color(hex: "F6AD55")
    static let moaiError = Color(hex: "FC8181")
    static let moaiErrorDark = Color(hex: "E53E3E")
    static let moaiInfo = Color(hex: "4299E1")
}

// MARK: - Adaptive Colors (Light/Dark Mode)

extension Color {
    
    /// Background color - adapts to color scheme
    static let moaiBackground = Color(
        light: Color(hex: "F7FAFC"),
        dark: Color(hex: "1A202C")
    )
    
    /// Surface color for cards and panels
    static let moaiSurface = Color(
        light: Color(hex: "FFFFFF"),
        dark: Color(hex: "2D3748")
    )
    
    /// Elevated surface color
    static let moaiSurfaceElevated = Color(
        light: Color(hex: "EDF2F7"),
        dark: Color(hex: "4A5568")
    )
    
    /// Border color
    static let moaiBorder = Color(
        light: Color(hex: "E2E8F0"),
        dark: Color(hex: "4A5568")
    )
    
    /// Primary text color
    static let moaiTextPrimary = Color(
        light: Color(hex: "1A202C"),
        dark: Color(hex: "F7FAFC")
    )
    
    /// Secondary text color
    static let moaiTextSecondary = Color(
        light: Color(hex: "4A5568"),
        dark: Color(hex: "E2E8F0")
    )
    
    /// Tertiary text color
    static let moaiTextTertiary = Color(
        light: Color(hex: "718096"),
        dark: Color(hex: "A0AEC0")
    )
}

// MARK: - Color Initializer with Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
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
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Creates an adaptive color that changes based on color scheme
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Color Scheme Extension for SwiftUI

#if canImport(AppKit)
import AppKit

extension Color {
    /// NSColor adapter for adaptive colors
    init(nsColor: NSColor) {
        self.init(nsColor)
    }
}
#endif

// MARK: - Preview

#Preview("Color Palette") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // Primary Colors
            GroupBox("Primary (Moai Stone)") {
                HStack(spacing: 16) {
                    ColorSquare(color: .moaiStone, name: "Stone")
                    ColorSquare(color: .moaiDark, name: "Dark")
                    ColorSquare(color: .moaiLight, name: "Light")
                }
            }
            
            // Accent Colors
            GroupBox("Accent (Security Green)") {
                HStack(spacing: 16) {
                    ColorSquare(color: .securityGreen, name: "Green")
                    ColorSquare(color: .securityGreenDark, name: "Dark")
                    ColorSquare(color: .securityGreenLight, name: "Light")
                }
            }
            
            // Semantic Colors
            GroupBox("Semantic") {
                HStack(spacing: 16) {
                    ColorSquare(color: .moaiSuccess, name: "Success")
                    ColorSquare(color: .moaiWarning, name: "Warning")
                    ColorSquare(color: .moaiError, name: "Error")
                    ColorSquare(color: .moaiInfo, name: "Info")
                }
            }
            
            // Adaptive Colors
            GroupBox("Adaptive (changes with dark mode)") {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        ColorSquare(color: .moaiBackground, name: "Background")
                        ColorSquare(color: .moaiSurface, name: "Surface")
                        ColorSquare(color: .moaiBorder, name: "Border")
                    }
                    HStack(spacing: 16) {
                        ColorSquare(color: .moaiTextPrimary, name: "Text Primary")
                        ColorSquare(color: .moaiTextSecondary, name: "Secondary")
                        ColorSquare(color: .moaiTextTertiary, name: "Tertiary")
                    }
                }
            }
        }
        .padding()
    }
    .frame(width: 500, height: 600)
}

struct ColorSquare: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.moaiBorder, lineWidth: 1)
                )
            Text(name)
                .font(.caption)
                .foregroundStyle(.moaiTextSecondary)
        }
    }
}
