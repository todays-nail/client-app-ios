//
//  SkeletonBlock.swift
//  NailClient
//

import SwiftUI

public enum SkeletonShapeStyle {
    case rounded
    case capsule
    case circle
}

public struct SkeletonBlock: View {
    public let width: CGFloat?
    public let height: CGFloat
    public let cornerRadius: CGFloat
    public let shapeStyle: SkeletonShapeStyle

    public init(
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

    public var body: some View {
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
