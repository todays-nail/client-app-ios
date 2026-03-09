//
//  ProfileDesignTokens.swift
//  NailClient
//

import SwiftUI

public enum ProfileDesignTokens {
    public static let pageBackground = AppColorTokens.background
    public static let cardBackground = AppColorTokens.cardBackground
    public static let cardBorder = AppColorTokens.border

    public static let primaryText = AppColorTokens.textPrimary
    public static let secondaryText = AppColorTokens.textSecondary
    public static let sectionTitle = AppColorTokens.textTertiary

    public static let accent = BrandColorTokens.primary
    public static let mutedAccent = Color.dynamic(lightHex: 0xC7CCD6, darkHex: 0x526077)

    public static let heroNameStyle: Font.TextStyle = .title3
    public static let cardTitleStyle: Font.TextStyle = .title3
    public static let cardSubtitleStyle: Font.TextStyle = .subheadline
    public static let ringCenterStyle: Font.TextStyle = .headline
    public static let insightItemStyle: Font.TextStyle = .subheadline
    public static let sectionTitleStyle: Font.TextStyle = .footnote
    public static let menuItemStyle: Font.TextStyle = .headline
    public static let actionStyle: Font.TextStyle = .callout

    public static let horizontalPadding: CGFloat = AppSpacingTokens.md
    public static let sectionSpacing: CGFloat = AppSpacingTokens.md
    public static let cardCornerRadius: CGFloat = AppRadiusTokens.md
    public static let groupedCardCornerRadius: CGFloat = AppRadiusTokens.md

    public static let styleCardPadding: CGFloat = AppSpacingTokens.md
    public static let styleCardRingSize: CGFloat = 90
    public static let styleCardRingLineWidth: CGFloat = 8
    public static let styleCardRowSpacing: CGFloat = AppSpacingTokens.sm
    public static let styleProgressBarHeight: CGFloat = 6
    public static let styleProgressTrack = AppColorTokens.border

    public static let heroAvatarSize: CGFloat = 100
    public static let heroAvatarBorderWidth: CGFloat = 4
    public static let heroCameraBadgeSize: CGFloat = 34
    public static let heroCameraIconSize: CGFloat = 14
    public static let heroSectionSpacing: CGFloat = AppSpacingTokens.xs
    public static let heroNameEditSpacing: CGFloat = AppSpacingTokens.xs
    public static let heroEditButtonSize: CGFloat = 28
    public static let heroEditIconSize: CGFloat = 12
    public static let heroAvatarFill = Color.dynamic(lightHex: 0xF2C7A4, darkHex: 0x4A3930)
    public static let heroAvatarBorder = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0x2A3446)
    public static let heroAvatarPlaceholder = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0xE2E8F3)
    public static let heroEditIconColor = primaryText
    public static let heroEditButtonBackground = cardBackground
    public static let heroEditButtonBorder = cardBorder

    public static let menuIconBoxSize: CGFloat = 34
    public static let menuIconSize: CGFloat = 15
    public static let menuChevronSize: CGFloat = 14
    public static let menuRowHorizontalPadding: CGFloat = AppSpacingTokens.md
    public static let menuRowVerticalPadding: CGFloat = AppSpacingTokens.sm
    public static let menuDividerLeading: CGFloat = 58

    public static let destructive = Color.dynamic(lightHex: 0xDC3F31, darkHex: 0xFF7468)

    public static let editSheetContentPadding: CGFloat = AppSpacingTokens.md
    public static let editSheetCardCornerRadius: CGFloat = AppRadiusTokens.md
    public static let editSheetFieldCornerRadius: CGFloat = AppRadiusTokens.sm
    public static let editSheetFieldVerticalPadding: CGFloat = AppSpacingTokens.sm
    public static let editSheetBottomInsetPadding: CGFloat = AppSpacingTokens.md
    public static let editSheetCardSpacing: CGFloat = AppSpacingTokens.sm

    public static let toastBackground = Color.dynamic(lightHex: 0x171A22, darkHex: 0xF3F5F8)
    public static let toastText = Color.dynamic(lightHex: 0xF3F5F8, darkHex: 0x171A22)
    public static let toastIcon = accent
    public static let toastTextStyle: Font.TextStyle = .subheadline
    public static let toastHorizontalPadding: CGFloat = AppSpacingTokens.md
    public static let toastVerticalPadding: CGFloat = AppSpacingTokens.sm
    public static let toastCornerRadius: CGFloat = AppRadiusTokens.sm
    public static let toastBottomPadding: CGFloat = AppSpacingTokens.xs

    public static let aiHistorySummaryBackground = AppColorTokens.cardSubtleBackground
    public static let aiHistorySummaryBorder = AppColorTokens.borderSoft
    public static let aiHistoryOriginalBadgeBackground = Color.dynamic(lightHex: 0xEEF3FF, darkHex: 0x273247)
    public static let aiHistoryOriginalBadgeText = Color.dynamic(lightHex: 0x35507A, darkHex: 0xC5D6F4)
    public static let aiHistoryRefinedBadgeBackground = Color.dynamic(lightHex: 0xFFECE8, darkHex: 0x4A2D29)
    public static let aiHistoryRefinedBadgeText = Color.dynamic(lightHex: 0xB84A38, darkHex: 0xFFC0B5)
    public static let aiHistoryPromptBackground = Color.dynamic(lightHex: 0xF7F9FC, darkHex: 0x202938)
}
