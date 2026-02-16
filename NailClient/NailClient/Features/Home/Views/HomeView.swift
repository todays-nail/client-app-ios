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
                        trendExploreCard(metrics: metrics)
                        aiFittingCard(metrics: metrics)
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

                    Text("트렌디한 네일 아트를 발견하고\n나만의 스타일을 찾아보세요.")
                        .font(.system(size: metrics.bodyFontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 4) {
                        Text("자세히 보기")
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

    private func aiFittingCard(metrics: HomeLayoutMetrics) -> some View {
        Button(action: onTapAI) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFF5F5), .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
                            .stroke(Color(hex: 0xE85B4E).opacity(0.14), lineWidth: 1)
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: metrics.decorationIconSize, weight: .light))
                    .foregroundStyle(Color(hex: 0xE85B4E).opacity(0.11))
                    .padding(.trailing, 18)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xE85B4E).opacity(0.12))
                        Image(systemName: "camera.fill")
                            .font(.system(size: metrics.cameraIconSize, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xE85B4E))
                    }
                    .frame(width: metrics.cameraBadgeSize, height: metrics.cameraBadgeSize)

                    Spacer()

                    Text("AI 가상 피팅")
                        .font(.system(size: metrics.titleFontSize, weight: .bold))
                        .foregroundStyle(Color(hex: 0x222222))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("내 손 사진 한 장으로\n퍼스널 컬러와 디자인을 매칭해보세요.")
                        .font(.system(size: metrics.bodyFontSize, weight: .regular))
                        .foregroundStyle(Color(hex: 0x6B6B6B))
                        .padding(.top, 6)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 6) {
                        Text("지금 시작하기")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: metrics.bodyFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, metrics.ctaVerticalPadding)
                    .background(Color(hex: 0xE85B4E), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 22)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                }
                .padding(metrics.contentPadding)
            }
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
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
    let decorationIconSize: CGFloat
    let cameraBadgeSize: CGFloat
    let cameraIconSize: CGFloat
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
        decorationIconSize = compactWidth ? 96 : 120
        cameraBadgeSize = compactWidth ? 52 : 56
        cameraIconSize = compactWidth ? 19 : 21
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
