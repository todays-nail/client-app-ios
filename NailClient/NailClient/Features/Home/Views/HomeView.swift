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
    @Environment(\.colorScheme) private var colorScheme

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
                    dynamicTypeSize: dynamicTypeSize,
                    safeAreaBottomInset: proxy.safeAreaInsets.bottom
                )

                ScrollView {
                    VStack(spacing: metrics.cardSpacing) {
                        HomeAIGenerationCardView(metrics: metrics, onTap: onTapAI)
                        HomeTrendExploreCardView(metrics: metrics, onTap: onTapFeed)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.topPadding)
                    .padding(.bottom, metrics.bottomPadding)
                }
                .background(homeBackgroundColor.ignoresSafeArea())
            }
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var homeBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: 0x0F1115) : Color(hex: 0xF9F9F8)
    }
}

#Preview {
    HomeView()
}
