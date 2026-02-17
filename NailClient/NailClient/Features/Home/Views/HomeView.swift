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
                let contentHeight = (
                    metrics.topPadding
                    + metrics.cardHeight * 2
                    + metrics.cardSpacing
                    + metrics.bottomPadding
                )
                let homeCards = VStack(spacing: metrics.cardSpacing) {
                    HomeAIGenerationCardView(metrics: metrics, onTap: onTapAI)
                    HomeTrendExploreCardView(metrics: metrics, onTap: onTapFeed)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, metrics.topPadding)
                .padding(.bottom, metrics.bottomPadding)

                if contentHeight > proxy.size.height {
                    ScrollView(showsIndicators: false) {
                        homeCards
                    }
                    .background(AppColorTokens.background.ignoresSafeArea())
                } else {
                    homeCards
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(AppColorTokens.background.ignoresSafeArea())
                }
            }
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HomeView()
}
