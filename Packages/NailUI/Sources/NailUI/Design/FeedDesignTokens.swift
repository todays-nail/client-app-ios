//
//  FeedDesignTokens.swift
//  NailClient
//

import SwiftUI

public enum FeedDesignTokens {
    public static let screenBackground = AppColorTokens.background
    public static let primaryText = AppColorTokens.textPrimary
    public static let secondaryText = AppColorTokens.textSecondary
    public static let accent = BrandColorTokens.primary

    public static let bannerBackground = Color.dynamic(lightHex: 0xEC6B63, darkHex: 0xB44E48)
    public static let bannerOverlay = Color.dynamic(lightHex: 0xD96C64, darkHex: 0xA64D49)
    public static let skeletonBase = Color.dynamic(lightHex: 0xE8ECF3, darkHex: 0x2A3342)
    public static let skeletonHighlight = Color.dynamic(lightHex: 0xF9FBFF, darkHex: 0x3A4658)
    public static let skeletonBackground = AppColorTokens.backgroundElevated
    public static let skeletonShimmerDuration: Double = 1.05
    public static let skeletonShimmerAngle: Double = 18

    public static let selectedChipBackground = BrandColorTokens.primary
    public static let selectedChipText = Color.white
    public static let unselectedChipBackground = AppColorTokens.chipBackground
    public static let unselectedChipText = AppColorTokens.chipText
    public static let chipBorder = AppColorTokens.chipBorder

    public static let detailBackground = AppColorTokens.backgroundElevated
    public static let detailCardBackground = AppColorTokens.cardBackground
    public static let detailSubCardBackground = AppColorTokens.cardSubtleBackground
    public static let detailBorder = AppColorTokens.border
    public static let detailDivider = AppColorTokens.line
    public static let detailPrimaryText = AppColorTokens.textPrimary
    public static let detailSecondaryText = AppColorTokens.textSecondary
    public static let detailTertiaryText = AppColorTokens.textTertiary
    public static let detailPlaceholderBackground = Color.dynamic(lightHex: 0xDDE2EB, darkHex: 0x283244)
    public static let detailLikeInactive = Color.dynamic(lightHex: 0x9CA6B8, darkHex: 0x7C8699)
    public static let detailTagText = Color.dynamic(lightHex: 0x384153, darkHex: 0xD4DBE7)
    public static let detailTagBackground = Color.dynamic(lightHex: 0xF5F6F9, darkHex: 0x242B38)
    public static let detailTagBorder = Color.dynamic(lightHex: 0xE6EAF1, darkHex: 0x323A49)
    public static let detailReviewStar = Color.dynamic(lightHex: 0xF6B81B, darkHex: 0xF4C95A)
    public static let detailStudioFill = AppColorTokens.warmFill
    public static let detailStudioIcon = AppColorTokens.warmText
    public static let detailActionBackground = AppColorTokens.cardBackground
    public static let detailActionBorder = AppColorTokens.borderSoft
    public static let detailActionText = AppColorTokens.textPrimary

    public static let horizontalPadding: CGFloat = AppSpacingTokens.md
    public static let sectionSpacing: CGFloat = AppSpacingTokens.xl
    public static let bannerToChipExtraSpacing: CGFloat = AppSpacingTokens.xxxl
    public static let chipToFeedSpacing: CGFloat = AppSpacingTokens.xxs
    public static let headerToContentSpacing: CGFloat = AppSpacingTokens.xxs
    public static let chipHeaderBottomSpacing: CGFloat = AppSpacingTokens.xs
    public static let scheduleSheetHeight: CGFloat = 420
    public static let scheduleSheetHorizontalPadding: CGFloat = AppSpacingTokens.lg
    public static let scheduleSheetSectionSpacing: CGFloat = AppSpacingTokens.md
    public static let scheduleSheetPickerHeight: CGFloat = 170
    public static let bannerCornerRadius: CGFloat = AppRadiusTokens.xl

    public static let feedGridColumnCount: Int = 3
    public static let feedGridSpacing: CGFloat = AppSpacingTokens.xxs
    public static let feedItemAspectRatio: CGFloat = 1.0
    public static let feedBadgePadding: CGFloat = AppSpacingTokens.xs
    public static let feedListSkeletonItemCount: Int = 12
}
