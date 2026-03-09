//
//  AIGenerationDesignTokens.swift
//  NailClient
//

import SwiftUI

public enum AIGenerationDesignTokens {
    public static let screenBackground = AppColorTokens.background
    public static let accent = FeedDesignTokens.accent
    public static let primaryText = AppColorTokens.textPrimary
    public static let secondaryText = AppColorTokens.textSecondary
    public static let cardBackground = AppColorTokens.cardBackground
    public static let cardSubtleBackground = AppColorTokens.cardSubtleBackground
    public static let border = AppColorTokens.border
    public static let dashedBorder = Color.dynamic(lightHex: 0xCCD3DF, darkHex: 0x445066)
    public static let placeholder = Color.dynamic(lightHex: 0xB0B8C6, darkHex: 0x8390A5)
    public static let chipUnselectedBackground = AppColorTokens.inputBackground
    public static let chipUnselectedText = Color.dynamic(lightHex: 0x4A5568, darkHex: 0xCFD6E3)
    public static let shapeFill = Color.dynamic(lightHex: 0xF3ECEC, darkHex: 0x352A2A)
    public static let noticeTint = Color.dynamic(lightHex: 0xE98078, darkHex: 0xFF9C92)
    public static let generationOverlayScrim = Color.black.opacity(0.32)
    public static let generationModalBackground = AppColorTokens.cardBackground
    public static let globalBannerSuccessBackground = Color.dynamic(lightHex: 0xEAF6EF, darkHex: 0x1F3327)
    public static let globalBannerFailureBackground = Color.dynamic(lightHex: 0xFDECEC, darkHex: 0x3A2326)
    public static let globalBannerBorder = AppColorTokens.border
    public static let globalBannerPrimaryText = AppColorTokens.textPrimary
    public static let globalBannerSecondaryText = AppColorTokens.textSecondary
    public static let globalBannerSuccessIcon = Color.dynamic(lightHex: 0x1E8A4A, darkHex: 0x6CE39E)
    public static let globalBannerFailureIcon = Color.dynamic(lightHex: 0xC23B3B, darkHex: 0xFF8B8B)
    public static let globalBannerCTA = accent
    public static let globalBannerCloseIcon = AppColorTokens.textSecondary
    public static let globalBannerCloseBackground = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0x1E2530)

    public static let sectionTitleStyle: Font.TextStyle = .title3
    public static let sectionBadgeStyle: Font.TextStyle = .headline
    public static let fieldTitleStyle: Font.TextStyle = .headline
    public static let bodyStyle: Font.TextStyle = .body
    public static let secondaryBodyStyle: Font.TextStyle = .subheadline
    public static let metaStyle: Font.TextStyle = .footnote
    public static let chipStyle: Font.TextStyle = .subheadline
    public static let ctaStyle: Font.TextStyle = .headline

    public static let pageHorizontalPadding: CGFloat = AppSpacingTokens.md
    public static let sectionSpacing: CGFloat = AppSpacingTokens.xl
    public static let cardCornerRadius: CGFloat = AppRadiusTokens.lg
}
