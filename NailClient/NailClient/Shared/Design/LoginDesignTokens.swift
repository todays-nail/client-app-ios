//
//  LoginDesignTokens.swift
//  NailClient
//
//  Created by Codex.
//

import SwiftUI

enum LoginDesignTokens {
    // Colors (match HTML/CSS tokens)
    static let bgBase = AppColorTokens.background
    static let peachGlow = Color.dynamic(lightHex: 0xFDCFBB, darkHex: 0xC78271)
    static let coralGlow = Color.dynamic(lightHex: 0xE85B4E, darkHex: 0xC45045)
    static let borderLight = AppColorTokens.border
    static let textMain = AppColorTokens.textPrimary
    static let textMuted = AppColorTokens.textSecondary
    static let kakaoYellow = Color(hex: 0xFEE500)

    // HTML: Profile onboarding tokens
    static let primaryHTML = Color(hex: 0xE85C4F)
    static let brandPrimary = Color(hex: 0xDC5945)
    static let backgroundLightHTML = Color(hex: 0xF8F6F6)
    static let backgroundDarkHTML = Color(hex: 0x211211)

    // Layout
    static let maxContentWidth: CGFloat = 340
    static let minScreenHeight: CGFloat = 884
}
