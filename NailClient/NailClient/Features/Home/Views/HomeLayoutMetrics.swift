//
//  HomeLayoutMetrics.swift
//  NailClient
//

import SwiftUI

struct HomeLayoutMetrics {
    let horizontalPadding: CGFloat = 20
    let topPadding: CGFloat = 20
    let cardSpacing: CGFloat = 20
    let cardCornerRadius: CGFloat = 26
    let bottomPadding: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let contentPadding: CGFloat
    let titleFontSize: CGFloat
    let bodyFontSize: CGFloat
    let badgeFontSize: CGFloat
    let ctaVerticalPadding: CGFloat

    init(containerWidth: CGFloat, dynamicTypeSize: DynamicTypeSize, safeAreaBottomInset: CGFloat) {
        let availableWidth = max(containerWidth, 0)
        let calculatedWidth = min(max(availableWidth - (horizontalPadding * 2), 0), 400)
        let compactWidth = availableWidth <= 390
        let dynamicScale = Self.dynamicScale(for: dynamicTypeSize)

        cardWidth = calculatedWidth
        cardHeight = cardWidth * (5.0 / 4.0) * 1.10
        contentPadding = compactWidth ? 22 : 26
        titleFontSize = min((compactWidth ? 29 : 32) * dynamicScale, compactWidth ? 34 : 36)
        bodyFontSize = min((compactWidth ? 15 : 16) * dynamicScale, 20)
        badgeFontSize = min((compactWidth ? 12 : 13) * dynamicScale, 16)
        ctaVerticalPadding = compactWidth ? 13 : 14
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
