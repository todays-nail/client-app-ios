//
//  HomeView.swift
//  NailClient
//

import SwiftUI
import NailUI

struct HomeView: View {
    let onTapAI: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var showWebRedirectAlert: Bool = false
    @State private var showWebOpenFailedAlert: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let ownerAppURL = URL(string: "https://owner-app-tawny.vercel.app")!

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
                        showWebRedirectAlert = true
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
            .alert("웹 페이지로 이동하시겠습니까?", isPresented: $showWebRedirectAlert) {
                Button("취소", role: .cancel) { }
                Button("이동") {
                    openURL(ownerAppURL) { accepted in
                        if !accepted {
                            showWebOpenFailedAlert = true
                        }
                    }
                }
            } message: {
                Text("사장님 모집 및 서비스 소개 페이지(https://owner-app-tawny.vercel.app)로 이동합니다.")
            }
            .alert("페이지를 열 수 없어요", isPresented: $showWebOpenFailedAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("브라우저에서 https://owner-app-tawny.vercel.app 을 직접 열어주세요.")
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
