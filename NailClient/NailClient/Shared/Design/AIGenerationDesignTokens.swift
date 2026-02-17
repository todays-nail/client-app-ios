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

    static let sectionTitleStyle: Font.TextStyle = .title3
    static let sectionBadgeStyle: Font.TextStyle = .headline
    static let fieldTitleStyle: Font.TextStyle = .headline
    static let bodyStyle: Font.TextStyle = .body
    static let secondaryBodyStyle: Font.TextStyle = .subheadline
    static let metaStyle: Font.TextStyle = .footnote
    static let chipStyle: Font.TextStyle = .subheadline
    static let ctaStyle: Font.TextStyle = .headline

    static let pageHorizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let cardCornerRadius: CGFloat = 18
}
