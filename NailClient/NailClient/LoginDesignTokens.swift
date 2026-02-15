//
//  LoginDesignTokens.swift
//  NailClient
//
//  Created by Codex.
//

import SwiftUI

enum LoginDesignTokens {
    // Colors (match HTML/CSS tokens)
    static let bgBase = Color(hex: 0xF9F9F8)
    static let peachGlow = Color(hex: 0xFDCFBB)
    static let coralGlow = Color(hex: 0xE85B4E)
    static let borderLight = Color(hex: 0xF0EEEB)
    static let textMain = Color(hex: 0x1A1A1A)
    static let textMuted = Color(hex: 0x727272)
    static let kakaoYellow = Color(hex: 0xFEE500)

    // HTML: Profile onboarding tokens
    static let primaryHTML = Color(hex: 0xE85C4F)
    static let backgroundLightHTML = Color(hex: 0xF8F6F6)
    static let backgroundDarkHTML = Color(hex: 0x211211)

    // Layout
    static let maxContentWidth: CGFloat = 340
    static let minScreenHeight: CGFloat = 884
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
