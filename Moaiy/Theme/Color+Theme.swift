//
//  Color+Theme.swift
//  Moaiy
//
//  Moaiy brand colors
//

import SwiftUI

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
    
    /// Accent color - Gold (like the sunset on Easter Island)
    static let moiayAccent = Color(
        red: 212 / 255,
        green: 175 / 255,
        blue: 55 / 255
    )
    
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
}
