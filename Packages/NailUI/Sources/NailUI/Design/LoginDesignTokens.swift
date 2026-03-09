//
//  LoginDesignTokens.swift
//  NailClient
//
//  Created by Codex.
//

import SwiftUI

public enum LoginDesignTokens {
    // Colors (match HTML/CSS tokens)
    public static let bgBase = AppColorTokens.background
    public static let peachGlow = Color.dynamic(lightHex: 0xFDCFBB, darkHex: 0xC78271)
    public static let coralGlow = Color.dynamic(lightHex: 0xE85B4E, darkHex: 0xC45045)
    public static let borderLight = AppColorTokens.border
    public static let textMain = AppColorTokens.textPrimary
    public static let textMuted = AppColorTokens.textSecondary
    public static let kakaoYellow = Color(hex: 0xFEE500)

    // HTML: Profile onboarding tokens
    public static let primaryHTML = BrandColorTokens.primary
    public static let brandPrimary = BrandColorTokens.primary
    public static let backgroundLightHTML = Color(hex: 0xF8F6F6)
    public static let backgroundDarkHTML = Color(hex: 0x211211)

    // Layout
    public static let maxContentWidth: CGFloat = 340
    public static let minScreenHeight: CGFloat = 884
}
