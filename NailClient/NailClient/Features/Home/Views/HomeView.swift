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
                    dynamicTypeSize: dynamicTypeSize,
                    safeAreaBottomInset: proxy.safeAreaInsets.bottom
                )

                ScrollView {
                    VStack(spacing: metrics.cardSpacing) {
                        aiGenerationCard(metrics: metrics)
                        trendExploreCard(metrics: metrics)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.topPadding)
                    .padding(.bottom, metrics.bottomPadding)
                }
                .background(Color(hex: 0xF9F9F8).ignoresSafeArea())
            }
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func trendExploreCard(metrics: HomeLayoutMetrics) -> some View {
        Button(action: onTapFeed) {
            ZStack(alignment: .bottomLeading) {
                Image("home_trend_card_bg")
                    .resizable()
                    .scaledToFill()

                LinearGradient(
                    colors: [
                        .black.opacity(0.72),
                        .black.opacity(0.26),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Trend")
                        .font(.system(size: metrics.badgeFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.20), in: Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text("디자인 탐색")
                        .font(.system(size: metrics.titleFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("디자인 탐색부터 예약까지\n원스톱으로 연결해보세요.")
                        .font(.system(size: metrics.bodyFontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 4) {
                        Text("원스톱 시작하기")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: metrics.badgeFontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                }
                .padding(metrics.contentPadding)
            }
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func aiGenerationCard(metrics: HomeLayoutMetrics) -> some View {
        Button(action: onTapAI) {
            ZStack(alignment: .topLeading) {
                Image("home_ai_generate_card_bg")
                    .resizable()
                    .scaledToFill()

                LinearGradient(
                    colors: [
                        .black.opacity(0.76),
                        .black.opacity(0.42),
                        .black.opacity(0.24)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                RadialGradient(
                    colors: [
                        Color(hex: 0xEA5D51).opacity(0.52),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 220
                )

                VStack(alignment: .leading, spacing: 0) {
                    Label("AI GENERATION", systemImage: "sparkles")
                        .font(.system(size: metrics.badgeFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.22), in: Capsule())

                    Spacer()

                    Text("고민말고 AI로 오늘 네일")
                        .font(.system(size: metrics.titleFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text("모든 디자인을 내 손에 AI로 적용해\n미리 확인하고 네일을 받아보세요.")
                        .font(.system(size: metrics.bodyFontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.top, 6)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Text("사진 업로드 · 스타일 선택 · 즉시 생성")
                        .font(.system(size: metrics.badgeFontSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.top, 12)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        Text("AI 네일 생성하기")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: metrics.bodyFontSize, weight: .bold))
                    .foregroundStyle(Color(hex: 0xD65548))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, metrics.ctaVerticalPadding)
                    .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 18)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                }
                .padding(metrics.contentPadding)
            }
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeLayoutMetrics {
    let horizontalPadding: CGFloat = 20
    let topPadding: CGFloat = 20
    let cardSpacing: CGFloat = 20
    let cardCornerRadius: CGFloat = 26
    let bottomPadding: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let contentPadding: CGFloat
    let titleFontSize: CGFloat
    let bodyFontSize: CGFloat
    let badgeFontSize: CGFloat
    let ctaVerticalPadding: CGFloat

    init(containerWidth: CGFloat, dynamicTypeSize: DynamicTypeSize, safeAreaBottomInset: CGFloat) {
        let availableWidth = max(containerWidth, 0)
        let calculatedWidth = min(max(availableWidth - (horizontalPadding * 2), 0), 400)
        let compactWidth = availableWidth <= 390
        let dynamicScale = Self.dynamicScale(for: dynamicTypeSize)

        cardWidth = calculatedWidth
        cardHeight = cardWidth * (5.0 / 4.0)
        contentPadding = compactWidth ? 22 : 26
        titleFontSize = min((compactWidth ? 29 : 32) * dynamicScale, compactWidth ? 34 : 36)
        bodyFontSize = min((compactWidth ? 15 : 16) * dynamicScale, 20)
        badgeFontSize = min((compactWidth ? 12 : 13) * dynamicScale, 16)
        ctaVerticalPadding = compactWidth ? 13 : 14
        bottomPadding = max(36, safeAreaBottomInset + 28)
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

#Preview {
    HomeView()
}
