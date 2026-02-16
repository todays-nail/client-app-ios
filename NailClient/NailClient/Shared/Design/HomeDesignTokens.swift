//
//  HomeDesignTokens.swift
//  NailClient
//

import SwiftUI

enum HomeDesignTokens {
    static let screenBackground = Color(hex: 0xF8F8F8)
    static let primaryText = Color(hex: 0x1B223A)
    static let accent = Color(hex: 0xEA5D51)

    static let bannerBackground = Color(hex: 0xEC6B63)
    static let bannerOverlay = Color(hex: 0xD96C64)

    static let selectedChipBackground = Color(hex: 0xEA5D51)
    static let selectedChipText = Color.white
    static let unselectedChipBackground = Color(hex: 0xE9EDF2)
    static let unselectedChipText = Color(hex: 0x243C5A)
    static let chipBorder = Color(hex: 0xE0E4EA)

    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 22
    static let bannerToChipExtraSpacing: CGFloat = 26
    static let chipToFeedSpacing: CGFloat = 8
    static let headerToContentSpacing: CGFloat = 2
    static let bannerCornerRadius: CGFloat = 24

    static let feedGridColumnCount: Int = 3
    static let feedGridSpacing: CGFloat = 1
    static let feedItemAspectRatio: CGFloat = 1.0
    static let feedBadgePadding: CGFloat = 8
}
