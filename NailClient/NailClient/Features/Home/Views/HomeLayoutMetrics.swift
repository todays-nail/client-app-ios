//
//  HomeLayoutMetrics.swift
//  NailClient
//

import SwiftUI

struct HomeLayoutMetrics {
    let horizontalPadding: CGFloat = 20
    let topPadding: CGFloat = 14
    let cardSpacing: CGFloat = 18
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
        safeAreaBottomInset _: CGFloat
    ) {
        let availableWidth = max(containerWidth, 0)
        let availableHeight = max(containerHeight, 0)
        let calculatedWidth = min(max(availableWidth - (horizontalPadding * 2), 0), 400)
        let compactWidth = calculatedWidth <= 360
        let wideWidth = availableWidth >= 700
        let dynamicScale = Self.dynamicScale(for: dynamicTypeSize)

        let cardAspectRatio: CGFloat
        if compactWidth {
            cardAspectRatio = 1.34
        } else if wideWidth {
            cardAspectRatio = 1.32
        } else {
            cardAspectRatio = 1.36
        }
        let proportionalHeight = calculatedWidth * cardAspectRatio
        let viewportCap = min(availableHeight * 0.68, 580)
        let viewportFloor: CGFloat = compactWidth ? 448 : 472

        cardWidth = calculatedWidth
        cardHeight = min(max(proportionalHeight, viewportFloor), viewportCap)
        contentPadding = compactWidth ? 20 : 24
        aiContentLeadingPadding = contentPadding + (compactWidth ? 3 : 4)
        titleFontSize = min((compactWidth ? 28 : 31) * dynamicScale, compactWidth ? 33 : 35)
        bodyFontSize = min((compactWidth ? 14.5 : 15.5) * dynamicScale, 19)
        badgeFontSize = min((compactWidth ? 12 : 13) * dynamicScale, 16)
        ctaVerticalPadding = compactWidth ? 12 : 13
        aiCTATopPadding = compactWidth ? 14 : 16
        // ScrollView/TabView safe area already protects bottom content.
        // Using safeAreaBottomInset here can over-allocate space and create extra scroll.
        bottomPadding = compactWidth ? 8 : 10
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
