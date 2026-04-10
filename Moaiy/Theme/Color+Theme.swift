//
//  Color+Theme.swift
//  Moaiy
//
//  Moaiy brand colors
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

enum MoaiyUI {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    enum Shadow {
        static let cardOpacity: Double = 0.06
        static let cardRadius: CGFloat = 4
        static let cardYOffset: CGFloat = 1

        static let overlayOpacity: Double = 0.16
        static let overlayRadius: CGFloat = 24
        static let overlayYOffset: CGFloat = 6
    }

    enum Typography {
        static let sheetTitle: Font = .title2.weight(.semibold)
        static let sheetSubtitle: Font = .subheadline
        static let sheetBody: Font = .body
        static let fieldLabel: Font = .subheadline
        static let caption: Font = .caption
        static let button: Font = .body
    }

    enum IconSize {
        static let sheetHero: CGFloat = 48
        static let closeButton: CGFloat = 18
    }

    static let animationFast: Double = 0.12
    static let animationNormal: Double = 0.18
}

extension Color {
    // MARK: - Brand Colors
    
    /// Primary brand color - Deep blue-gray (like the Moai stone)
    static let moiayPrimary = Color(
        red: 58 / 255,
        green: 61 / 255,
        blue: 66 / 255
    )
    
    /// Secondary brand color - Light gray
    static let moiaySecondary = Color(
        red: 107 / 255,
        green: 114 / 255,
        blue: 128 / 255
    )

    /// Alias for compatibility with corrected spelling.
    static let moaiyPrimary = moiayPrimary

    /// Alias for compatibility with corrected spelling.
    static let moaiySecondary = moiaySecondary
    
    /// Accent color compatibility alias (mapped to v2 accent).
    static let moaiyAccent = moaiyAccentV2
    
    // MARK: - Semantic Colors
    
    /// Success color - Green
    static let moiaySuccess = Color(
        red: 16 / 255,
        green: 185 / 255,
        blue: 129 / 255
    )
    
    /// Warning color - Orange
    static let moiayWarning = Color(
        red: 245 / 255,
        green: 158 / 255,
        blue: 11 / 255
    )
    
    /// Error color - Red
    static let moiayError = Color(
        red: 239 / 255,
        green: 68 / 255,
        blue: 68 / 255
    )
    
    /// Info color - Blue
    static let moiayInfo = Color(
        red: 59 / 255,
        green: 130 / 255,
        blue: 246 / 255
    )

    /// Alias for compatibility with corrected spelling.
    static let moaiySuccess = moiaySuccess

    /// Alias for compatibility with corrected spelling.
    static let moaiyWarning = moiayWarning

    /// Alias for compatibility with corrected spelling.
    static let moaiyError = moiayError

    /// Alias for compatibility with corrected spelling.
    static let moaiyInfo = moiayInfo

    // MARK: - UI v2 Semantic Colors

#if os(macOS)
    private static func moaiyDynamic(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                return match == .darkAqua ? dark : light
            }
        )
    }
#endif

    /// App-level background color.
    static let moaiySurfaceBackground = moaiyDynamic(
        light: NSColor(red: 245 / 255, green: 246 / 255, blue: 248 / 255, alpha: 1),
        dark: NSColor(red: 22 / 255, green: 24 / 255, blue: 29 / 255, alpha: 1)
    )

    /// Primary card and sheet surface.
    static let moaiySurfacePrimary = moaiyDynamic(
        light: NSColor.white,
        dark: NSColor(red: 30 / 255, green: 34 / 255, blue: 43 / 255, alpha: 1)
    )

    /// Secondary elevated surface.
    static let moaiySurfaceSecondary = moaiyDynamic(
        light: NSColor(red: 241 / 255, green: 243 / 255, blue: 246 / 255, alpha: 1),
        dark: NSColor(red: 37 / 255, green: 42 / 255, blue: 53 / 255, alpha: 1)
    )

    /// Primary text color.
    static let moaiyTextPrimary = moaiyDynamic(
        light: NSColor(red: 17 / 255, green: 19 / 255, blue: 23 / 255, alpha: 1),
        dark: NSColor(red: 243 / 255, green: 244 / 255, blue: 246 / 255, alpha: 1)
    )

    /// Secondary text color.
    static let moaiyTextSecondary = moaiyDynamic(
        light: NSColor(red: 89 / 255, green: 98 / 255, blue: 115 / 255, alpha: 1),
        dark: NSColor(red: 169 / 255, green: 179 / 255, blue: 198 / 255, alpha: 1)
    )

    /// Border color for cards and inputs.
    static let moaiyBorderPrimary = moaiyDynamic(
        light: NSColor(red: 217 / 255, green: 222 / 255, blue: 231 / 255, alpha: 1),
        dark: NSColor(red: 58 / 255, green: 66 / 255, blue: 82 / 255, alpha: 1)
    )

    /// Primary action accent color for v2.
    static let moaiyAccentV2 = moaiyDynamic(
        light: NSColor(red: 31 / 255, green: 107 / 255, blue: 255 / 255, alpha: 1),
        dark: NSColor(red: 109 / 255, green: 156 / 255, blue: 255 / 255, alpha: 1)
    )

    /// Focus ring color.
    static let moaiyFocusRing = moaiyDynamic(
        light: NSColor(red: 91 / 255, green: 140 / 255, blue: 255 / 255, alpha: 1),
        dark: NSColor(red: 143 / 255, green: 176 / 255, blue: 255 / 255, alpha: 1)
    )
}

extension View {
    /// Applies adaptive sizing for macOS modal sheets.
    func moaiyModalAdaptiveSize(
        minWidth: CGFloat = 380,
        idealWidth: CGFloat = 520,
        maxWidth: CGFloat = 760,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil
    ) -> some View {
        frame(
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: .topLeading
        )
    }

    /// Standard card surface for grouped sections inside modals.
    func moaiyModalCard(cornerRadius: CGFloat = MoaiyUI.Radius.lg) -> some View {
        padding(16)
            .background(Color.moaiySurfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.moaiyBorderPrimary.opacity(0.85), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(MoaiyUI.Shadow.cardOpacity),
                radius: MoaiyUI.Shadow.cardRadius,
                y: MoaiyUI.Shadow.cardYOffset
            )
    }

    /// Standard card style for list rows and content blocks.
    func moaiyCardStyle(cornerRadius: CGFloat = MoaiyUI.Radius.lg) -> some View {
        background(Color.moaiySurfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.moaiyBorderPrimary.opacity(0.8), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(MoaiyUI.Shadow.cardOpacity),
                radius: MoaiyUI.Shadow.cardRadius,
                y: MoaiyUI.Shadow.cardYOffset
            )
    }

    /// Standard highlighted banner style used by status/info/warning messages.
    func moaiyBannerStyle(
        tint: Color,
        cornerRadius: CGFloat = MoaiyUI.Radius.md
    ) -> some View {
        background(tint.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
