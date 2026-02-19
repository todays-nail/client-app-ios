//
//  ReservationDesignTokens.swift
//  NailClient
//

import SwiftUI

enum ReservationDesignTokens {
    static let screenBackground = AppColorTokens.background
    static let cardBackground = AppColorTokens.cardBackground
    static let cardBorder = AppColorTokens.border
    static let sectionTitleText = AppColorTokens.textPrimary
    static let secondaryText = AppColorTokens.textSecondary
    static let primaryText = AppColorTokens.textPrimary
    static let accent = FeedDesignTokens.accent
    static let mutedButtonBackground = AppColorTokens.cardSubtleBackground
    static let completedButtonBackground = Color.dynamic(lightHex: 0xEFEAE7, darkHex: 0x252E3D)
    static let tagBackground = Color.dynamic(lightHex: 0xF2ECE8, darkHex: 0x2A3342)
    static let dateTileBackground = Color.dynamic(lightHex: 0x2A1B17, darkHex: 0x3A4558)
    static let outlineButtonFill = AppColorTokens.cardBackground

    static let horizontalPadding: CGFloat = AppSpacingTokens.md
    static let sectionSpacing: CGFloat = AppSpacingTokens.xl
    static let cardCornerRadius: CGFloat = AppRadiusTokens.lg
    static let imageCornerRadius: CGFloat = AppRadiusTokens.md

    static let segmentHeight: CGFloat = 44
    static let heroImageHeight: CGFloat = 210
    static let ctaHeight: CGFloat = 48

    static let defaultUpcomingImageName: String = "natural"
}
