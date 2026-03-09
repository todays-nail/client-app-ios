//
//  ShimmerModifier.swift
//  NailClient
//

import SwiftUI

struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.2

    let isActive: Bool
    let duration: Double
    let angle: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !reduceMotion {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        FeedDesignTokens.skeletonHighlight.opacity(0.0),
                                        FeedDesignTokens.skeletonHighlight.opacity(0.85),
                                        FeedDesignTokens.skeletonHighlight.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: proxy.size.width * 0.52)
                            .rotationEffect(.degrees(angle))
                            .offset(x: phase * proxy.size.width * 1.9)
                            .onAppear {
                                phase = -1.2
                                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                                    phase = 1.2
                                }
                            }
                    }
                    .allowsHitTesting(false)
                }
            }
            .mask(content)
    }
}

public extension View {
    func shimmer(active: Bool = true) -> some View {
        modifier(
            ShimmerModifier(
                isActive: active,
                duration: FeedDesignTokens.skeletonShimmerDuration,
                angle: FeedDesignTokens.skeletonShimmerAngle
            )
        )
    }
}
