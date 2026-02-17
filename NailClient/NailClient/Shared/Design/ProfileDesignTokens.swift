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

    static let accent = Color(hex: 0xF3522E)
    static let mutedAccent = Color.dynamic(lightHex: 0xC7CCD6, darkHex: 0x526077)

    static let heroNameStyle: Font.TextStyle = .title3
    static let heroPhoneStyle: Font.TextStyle = .title2
    static let cardTitleStyle: Font.TextStyle = .title3
    static let cardSubtitleStyle: Font.TextStyle = .subheadline
    static let ringCenterStyle: Font.TextStyle = .headline
    static let insightItemStyle: Font.TextStyle = .subheadline
    static let sectionTitleStyle: Font.TextStyle = .footnote
    static let menuItemStyle: Font.TextStyle = .headline
    static let actionStyle: Font.TextStyle = .callout

    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let groupedCardCornerRadius: CGFloat = 14

    static let styleCardPadding: CGFloat = 14
    static let styleCardRingSize: CGFloat = 90
    static let styleCardRingLineWidth: CGFloat = 8
    static let styleCardRowSpacing: CGFloat = 10
    static let styleProgressBarHeight: CGFloat = 6
    static let styleProgressTrack = AppColorTokens.border

    static let heroAvatarSize: CGFloat = 100
    static let heroAvatarBorderWidth: CGFloat = 4
    static let heroCameraBadgeSize: CGFloat = 34
    static let heroCameraIconSize: CGFloat = 14
    static let heroSectionSpacing: CGFloat = 6
    static let heroAvatarFill = Color.dynamic(lightHex: 0xF2C7A4, darkHex: 0x4A3930)
    static let heroAvatarBorder = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0x2A3446)
    static let heroAvatarPlaceholder = Color.dynamic(lightHex: 0xFFFFFF, darkHex: 0xE2E8F3)

    static let menuIconBoxSize: CGFloat = 34
    static let menuIconSize: CGFloat = 15
    static let menuChevronSize: CGFloat = 14
    static let menuRowHorizontalPadding: CGFloat = 14
    static let menuRowVerticalPadding: CGFloat = 12
    static let menuDividerLeading: CGFloat = 58

    static let destructive = Color.dynamic(lightHex: 0xDC3F31, darkHex: 0xFF7468)

    static let editSheetContentPadding: CGFloat = 16
    static let editSheetCardCornerRadius: CGFloat = 16
    static let editSheetFieldCornerRadius: CGFloat = 10
    static let editSheetFieldVerticalPadding: CGFloat = 11
    static let editSheetBottomInsetPadding: CGFloat = 16
    static let editSheetCardSpacing: CGFloat = 12
}
