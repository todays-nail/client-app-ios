//
//  HomeView.swift
//  NailClient
//

import SwiftUI

struct HomeView: View {
    let onTapAI: () -> Void
    @State private var isTrendExploreComingSoonPresented: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        onTapAI: @escaping () -> Void = {}
    ) {
        self.onTapAI = onTapAI
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
                    HomeTrendExploreCardView(metrics: metrics) {
                        isTrendExploreComingSoonPresented = true
                    }
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
            .alert("곧 지원 예정", isPresented: $isTrendExploreComingSoonPresented) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("AI로 네일 디자인을 생성한 후, 견적•예약•시술 서비스를 제공할 예정입니다.")
            }
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
