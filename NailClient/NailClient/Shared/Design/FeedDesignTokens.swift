//
//  FeedDesignTokens.swift
//  NailClient
//

import SwiftUI

enum FeedDesignTokens {
    static let screenBackground = AppColorTokens.background
    static let primaryText = AppColorTokens.textPrimary
    static let secondaryText = AppColorTokens.textSecondary
    static let accent = BrandColorTokens.primary

    static let bannerBackground = Color.dynamic(lightHex: 0xEC6B63, darkHex: 0xB44E48)
    static let bannerOverlay = Color.dynamic(lightHex: 0xD96C64, darkHex: 0xA64D49)
    static let skeletonBase = Color.dynamic(lightHex: 0xE8ECF3, darkHex: 0x2A3342)
    static let skeletonHighlight = Color.dynamic(lightHex: 0xF9FBFF, darkHex: 0x3A4658)
    static let skeletonBackground = AppColorTokens.backgroundElevated
    static let skeletonShimmerDuration: Double = 1.05
    static let skeletonShimmerAngle: Double = 18

    static let selectedChipBackground = BrandColorTokens.primary
    static let selectedChipText = Color.white
    static let unselectedChipBackground = AppColorTokens.chipBackground
    static let unselectedChipText = AppColorTokens.chipText
    static let chipBorder = AppColorTokens.chipBorder

    static let detailBackground = AppColorTokens.backgroundElevated
    static let detailCardBackground = AppColorTokens.cardBackground
    static let detailSubCardBackground = AppColorTokens.cardSubtleBackground
    static let detailBorder = AppColorTokens.border
    static let detailDivider = AppColorTokens.line
    static let detailPrimaryText = AppColorTokens.textPrimary
    static let detailSecondaryText = AppColorTokens.textSecondary
    static let detailTertiaryText = AppColorTokens.textTertiary
    static let detailPlaceholderBackground = Color.dynamic(lightHex: 0xDDE2EB, darkHex: 0x283244)
    static let detailLikeInactive = Color.dynamic(lightHex: 0x9CA6B8, darkHex: 0x7C8699)
    static let detailTagText = Color.dynamic(lightHex: 0x384153, darkHex: 0xD4DBE7)
    static let detailTagBackground = Color.dynamic(lightHex: 0xF5F6F9, darkHex: 0x242B38)
    static let detailTagBorder = Color.dynamic(lightHex: 0xE6EAF1, darkHex: 0x323A49)
    static let detailReviewStar = Color.dynamic(lightHex: 0xF6B81B, darkHex: 0xF4C95A)
    static let detailStudioFill = AppColorTokens.warmFill
    static let detailStudioIcon = AppColorTokens.warmText
    static let detailActionBackground = AppColorTokens.cardBackground
    static let detailActionBorder = AppColorTokens.borderSoft
    static let detailActionText = AppColorTokens.textPrimary

    static let horizontalPadding: CGFloat = AppSpacingTokens.md
    static let sectionSpacing: CGFloat = AppSpacingTokens.xl
    static let bannerToChipExtraSpacing: CGFloat = AppSpacingTokens.xxxl
    static let chipToFeedSpacing: CGFloat = AppSpacingTokens.xxs
    static let headerToContentSpacing: CGFloat = AppSpacingTokens.xxs
    static let chipHeaderBottomSpacing: CGFloat = AppSpacingTokens.xs
    static let scheduleSheetHeight: CGFloat = 420
    static let scheduleSheetHorizontalPadding: CGFloat = AppSpacingTokens.lg
    static let scheduleSheetSectionSpacing: CGFloat = AppSpacingTokens.md
    static let scheduleSheetPickerHeight: CGFloat = 170
    static let bannerCornerRadius: CGFloat = 24

    static let feedGridColumnCount: Int = 3
    static let feedGridSpacing: CGFloat = AppSpacingTokens.xxs
    static let feedItemAspectRatio: CGFloat = 1.0
    static let feedBadgePadding: CGFloat = AppSpacingTokens.xs
    static let feedListSkeletonItemCount: Int = 12
}
