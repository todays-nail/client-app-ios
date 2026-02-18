//
//  HomeView.swift
//  NailClient
//

import SwiftUI

struct HomeView: View {
    let onTapFeed: () -> Void
    let onTapAI: () -> Void
    let onTapReservations: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        onTapFeed: @escaping () -> Void = {},
        onTapAI: @escaping () -> Void = {},
        onTapReservations: @escaping () -> Void = {}
    ) {
        self.onTapFeed = onTapFeed
        self.onTapAI = onTapAI
        self.onTapReservations = onTapReservations
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let metrics = HomeLayoutMetrics(
                    containerWidth: proxy.size.width,
                    containerHeight: proxy.size.height,
                    dynamicTypeSize: dynamicTypeSize,
                    safeAreaBottomInset: proxy.safeAreaInsets.bottom
                )
                let homeCards = VStack(spacing: metrics.cardSpacing) {
                    HomeAIGenerationCardView(metrics: metrics, onTap: onTapAI)
                    HomeTrendExploreCardView(metrics: metrics, onTap: onTapFeed)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)

                ScrollView(showsIndicators: false) {
                    homeCards
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(AppColorTokens.background.ignoresSafeArea())
            }
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("Home · Pro(393) · Large") {
    HomeView()
        .environment(\.dynamicTypeSize, .large)
        .frame(width: 393, height: 852)
}

#Preview("Home · Pro(393) · AX2") {
    HomeView()
        .environment(\.dynamicTypeSize, .accessibility2)
        .frame(width: 393, height: 852)
}

#Preview("Home · Pro Max(430) · Large") {
    HomeView()
        .environment(\.dynamicTypeSize, .large)
        .frame(width: 430, height: 932)
}

#Preview("Home · Pro Max(430) · AX2") {
    HomeView()
        .environment(\.dynamicTypeSize, .accessibility2)
        .frame(width: 430, height: 932)
}
