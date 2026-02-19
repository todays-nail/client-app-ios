//
//  AIGenerationDesignTokens.swift
//  NailClient
//

import SwiftUI

enum AIGenerationDesignTokens {
    static let screenBackground = AppColorTokens.background
    static let accent = FeedDesignTokens.accent
    static let primaryText = AppColorTokens.textPrimary
    static let secondaryText = AppColorTokens.textSecondary
    static let cardBackground = AppColorTokens.cardBackground
    static let cardSubtleBackground = AppColorTokens.cardSubtleBackground
    static let border = AppColorTokens.border
    static let dashedBorder = Color.dynamic(lightHex: 0xCCD3DF, darkHex: 0x445066)
    static let placeholder = Color.dynamic(lightHex: 0xB0B8C6, darkHex: 0x8390A5)
    static let chipUnselectedBackground = AppColorTokens.inputBackground
    static let chipUnselectedText = Color.dynamic(lightHex: 0x4A5568, darkHex: 0xCFD6E3)
    static let shapeFill = Color.dynamic(lightHex: 0xF3ECEC, darkHex: 0x352A2A)
    static let noticeTint = Color.dynamic(lightHex: 0xE98078, darkHex: 0xFF9C92)
    static let generationOverlayScrim = Color.black.opacity(0.32)
    static let generationModalBackground = AppColorTokens.cardBackground
    static let globalBannerSuccessBackground = Color.dynamic(lightHex: 0xEAF6EF, darkHex: 0x1F3327)
    static let globalBannerFailureBackground = Color.dynamic(lightHex: 0xFDECEC, darkHex: 0x3A2326)
    static let globalBannerBorder = AppColorTokens.border
    static let globalBannerPrimaryText = AppColorTokens.textPrimary
    static let globalBannerSecondaryText = AppColorTokens.textSecondary
    static let globalBannerSuccessIcon = Color.dynamic(lightHex: 0x1E8A4A, darkHex: 0x6CE39E)
    static let globalBannerFailureIcon = Color.dynamic(lightHex: 0xC23B3B, darkHex: 0xFF8B8B)
    static let globalBannerCTA = accent
    static let globalBannerCloseIcon = AppColorTokens.textSecondary
    static let globalBannerCloseBackground = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0x1E2530)

    static let sectionTitleStyle: Font.TextStyle = .title3
    static let sectionBadgeStyle: Font.TextStyle = .headline
    static let fieldTitleStyle: Font.TextStyle = .headline
    static let bodyStyle: Font.TextStyle = .body
    static let secondaryBodyStyle: Font.TextStyle = .subheadline
    static let metaStyle: Font.TextStyle = .footnote
    static let chipStyle: Font.TextStyle = .subheadline
    static let ctaStyle: Font.TextStyle = .headline

    static let pageHorizontalPadding: CGFloat = AppSpacingTokens.md
    static let sectionSpacing: CGFloat = AppSpacingTokens.xl
    static let cardCornerRadius: CGFloat = 18
}
