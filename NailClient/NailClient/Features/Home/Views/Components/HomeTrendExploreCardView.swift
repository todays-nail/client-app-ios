//
//  HomeTrendExploreCardView.swift
//  NailClient
//

import SwiftUI

struct HomeTrendExploreCardView: View {
    let metrics: HomeLayoutMetrics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
}
