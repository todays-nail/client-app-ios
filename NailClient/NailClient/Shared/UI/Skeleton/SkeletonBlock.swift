//
//  SkeletonBlock.swift
//  NailClient
//

import SwiftUI

enum SkeletonShapeStyle {
    case rounded
    case capsule
    case circle
}

struct SkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    let shapeStyle: SkeletonShapeStyle

    init(
        width: CGFloat? = nil,
        height: CGFloat,
        cornerRadius: CGFloat = 12,
        shapeStyle: SkeletonShapeStyle = .rounded
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.shapeStyle = shapeStyle
    }

    var body: some View {
        shapeView
            .frame(width: width, height: height)
            .shimmer()
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var shapeView: some View {
        switch shapeStyle {
        case .rounded:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(FeedDesignTokens.skeletonBase)
        case .capsule:
            Capsule(style: .continuous)
                .fill(FeedDesignTokens.skeletonBase)
        case .circle:
            Circle()
                .fill(FeedDesignTokens.skeletonBase)
        }
    }
}
