//
//  ProfileDesignTokens.swift
//  NailClient
//

import SwiftUI

enum ProfileDesignTokens {
    static let pageBackground = AppColorTokens.background
    static let cardBackground = AppColorTokens.cardBackground
    static let cardBorder = AppColorTokens.border

    static let primaryText = AppColorTokens.textPrimary
    static let secondaryText = AppColorTokens.textSecondary
    static let sectionTitle = AppColorTokens.textTertiary

    static let accent = BrandColorTokens.primary
    static let mutedAccent = Color.dynamic(lightHex: 0xC7CCD6, darkHex: 0x526077)

    static let heroNameStyle: Font.TextStyle = .title3
    static let cardTitleStyle: Font.TextStyle = .title3
    static let cardSubtitleStyle: Font.TextStyle = .subheadline
    static let ringCenterStyle: Font.TextStyle = .headline
    static let insightItemStyle: Font.TextStyle = .subheadline
    static let sectionTitleStyle: Font.TextStyle = .footnote
    static let menuItemStyle: Font.TextStyle = .headline
    static let actionStyle: Font.TextStyle = .callout

    static let horizontalPadding: CGFloat = AppSpacingTokens.md
    static let sectionSpacing: CGFloat = AppSpacingTokens.md
    static let cardCornerRadius: CGFloat = 16
    static let groupedCardCornerRadius: CGFloat = 14

    static let styleCardPadding: CGFloat = AppSpacingTokens.md
    static let styleCardRingSize: CGFloat = 90
    static let styleCardRingLineWidth: CGFloat = 8
    static let styleCardRowSpacing: CGFloat = AppSpacingTokens.sm
    static let styleProgressBarHeight: CGFloat = 6
    static let styleProgressTrack = AppColorTokens.border

    static let heroAvatarSize: CGFloat = 100
    static let heroAvatarBorderWidth: CGFloat = 4
    static let heroCameraBadgeSize: CGFloat = 34
    static let heroCameraIconSize: CGFloat = 14
    static let heroSectionSpacing: CGFloat = AppSpacingTokens.xs
    static let heroNameEditSpacing: CGFloat = AppSpacingTokens.xs
    static let heroEditButtonSize: CGFloat = 28
    static let heroEditIconSize: CGFloat = 12
    static let heroAvatarFill = Color.dynamic(lightHex: 0xF2C7A4, darkHex: 0x4A3930)
    static let heroAvatarBorder = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0x2A3446)
    static let heroAvatarPlaceholder = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0xE2E8F3)
    static let heroEditIconColor = primaryText
    static let heroEditButtonBackground = cardBackground
    static let heroEditButtonBorder = cardBorder

    static let menuIconBoxSize: CGFloat = 34
    static let menuIconSize: CGFloat = 15
    static let menuChevronSize: CGFloat = 14
    static let menuRowHorizontalPadding: CGFloat = AppSpacingTokens.md
    static let menuRowVerticalPadding: CGFloat = AppSpacingTokens.sm
    static let menuDividerLeading: CGFloat = 58

    static let destructive = Color.dynamic(lightHex: 0xDC3F31, darkHex: 0xFF7468)

    static let editSheetContentPadding: CGFloat = AppSpacingTokens.md
    static let editSheetCardCornerRadius: CGFloat = 16
    static let editSheetFieldCornerRadius: CGFloat = 10
    static let editSheetFieldVerticalPadding: CGFloat = AppSpacingTokens.sm
    static let editSheetBottomInsetPadding: CGFloat = AppSpacingTokens.md
    static let editSheetCardSpacing: CGFloat = AppSpacingTokens.sm

    static let toastBackground = Color.dynamic(lightHex: 0x171A22, darkHex: 0xF3F5F8)
    static let toastText = Color.dynamic(lightHex: 0xF3F5F8, darkHex: 0x171A22)
    static let toastIcon = accent
    static let toastTextStyle: Font.TextStyle = .subheadline
    static let toastHorizontalPadding: CGFloat = AppSpacingTokens.md
    static let toastVerticalPadding: CGFloat = AppSpacingTokens.sm
    static let toastCornerRadius: CGFloat = 12
    static let toastBottomPadding: CGFloat = AppSpacingTokens.xs

    static let aiHistorySummaryBackground = AppColorTokens.cardSubtleBackground
    static let aiHistorySummaryBorder = AppColorTokens.borderSoft
    static let aiHistoryOriginalBadgeBackground = Color.dynamic(lightHex: 0xEEF3FF, darkHex: 0x273247)
    static let aiHistoryOriginalBadgeText = Color.dynamic(lightHex: 0x35507A, darkHex: 0xC5D6F4)
    static let aiHistoryRefinedBadgeBackground = Color.dynamic(lightHex: 0xFFECE8, darkHex: 0x4A2D29)
    static let aiHistoryRefinedBadgeText = Color.dynamic(lightHex: 0xB84A38, darkHex: 0xFFC0B5)
    static let aiHistoryPromptBackground = Color.dynamic(lightHex: 0xF7F9FC, darkHex: 0x202938)
}
