//
//  HomeLayoutMetrics.swift
//  NailClient
//

import SwiftUI

struct HomeLayoutMetrics {
    let horizontalPadding: CGFloat = 20
    let topPadding: CGFloat = 12
    let cardSpacing: CGFloat = 16
    let cardCornerRadius: CGFloat = 26
    let bottomPadding: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let contentPadding: CGFloat
    let aiContentLeadingPadding: CGFloat
    let titleFontSize: CGFloat
    let bodyFontSize: CGFloat
    let badgeFontSize: CGFloat
    let ctaVerticalPadding: CGFloat
    let aiCTATopPadding: CGFloat

    init(
        containerWidth: CGFloat,
        containerHeight: CGFloat,
        dynamicTypeSize: DynamicTypeSize,
        safeAreaBottomInset: CGFloat
    ) {
        let availableWidth = max(containerWidth, 0)
        let availableHeight = max(containerHeight, 0)
        let calculatedWidth = min(max(availableWidth - (horizontalPadding * 2), 0), 400)
        let compactWidth = availableWidth <= 390
        let wideWidth = availableWidth >= 700
        let dynamicScale = Self.dynamicScale(for: dynamicTypeSize)
        let baseCardHeight = calculatedWidth * (5.0 / 4.0)
        let cardHeightMultiplier: CGFloat = if compactWidth {
            1.14
        } else if wideWidth {
            1.08
        } else {
            1.12
        }
        let viewportCappedCardHeight = min(baseCardHeight * cardHeightMultiplier, availableHeight * 0.60)

        cardWidth = calculatedWidth
        cardHeight = min(viewportCappedCardHeight, 520)
        contentPadding = compactWidth ? 22 : 26
        aiContentLeadingPadding = contentPadding + (compactWidth ? 5 : 6)
        titleFontSize = min((compactWidth ? 29 : 32) * dynamicScale, compactWidth ? 34 : 36)
        bodyFontSize = min((compactWidth ? 15 : 16) * dynamicScale, 20)
        badgeFontSize = min((compactWidth ? 12 : 13) * dynamicScale, 16)
        ctaVerticalPadding = compactWidth ? 13 : 14
        aiCTATopPadding = compactWidth ? 16 : 18
        bottomPadding = max(36, safeAreaBottomInset + 28)
    }

    private static func dynamicScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall:
            return 0.92
        case .small:
            return 0.95
        case .medium:
            return 0.98
        case .large:
            return 1.0
        case .xLarge:
            return 1.04
        case .xxLarge:
            return 1.08
        case .xxxLarge:
            return 1.12
        case .accessibility1:
            return 1.16
        case .accessibility2:
            return 1.2
        case .accessibility3:
            return 1.24
        case .accessibility4:
            return 1.28
        case .accessibility5:
            return 1.32
        @unknown default:
            return 1.0
        }
    }
}
