//
//  FittedAIImagesLayoutMetrics.swift
//  NailClient
//

import SwiftUI

struct FittedAIImagesLayoutMetrics: Equatable {
    static let fallbackContainerWidth: CGFloat = 390

    let columnCount: Int
    let spacing: CGFloat
    let containerWidth: CGFloat
    let tileSide: CGFloat

    var thumbnailTargetSize: CGSize {
        CGSize(width: tileSide, height: tileSide)
    }

    init(
        containerWidth: CGFloat,
        columnCount: Int = 3,
        spacing: CGFloat = 1
    ) {
        let resolvedColumnCount = max(columnCount, 1)
        let resolvedSpacing = max(spacing, 0)
        let resolvedWidth = max(containerWidth, 0)
        let totalSpacing = resolvedSpacing * CGFloat(resolvedColumnCount - 1)
        let availableWidth = max(resolvedWidth - totalSpacing, 0)

        self.columnCount = resolvedColumnCount
        self.spacing = resolvedSpacing
        self.containerWidth = resolvedWidth
        self.tileSide = floor(availableWidth / CGFloat(resolvedColumnCount))
    }
}
