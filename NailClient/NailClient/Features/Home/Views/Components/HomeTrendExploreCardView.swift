//
//  HomeTrendExploreCardView.swift
//  NailClient
//

import SwiftUI

struct HomeTrendExploreCardView: View {
    let metrics: HomeLayoutMetrics
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                Image("home_trend_card_bg")
                    .resizable()
                    .scaledToFill()

                LinearGradient(
                    colors: [
                        .black.opacity(0.76),
                        .black.opacity(0.34),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                VStack(alignment: .leading, spacing: 9) {
                    Text("ONE STOP")
                        .font(.system(size: metrics.badgeFontSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.20))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text("디자인 탐색")
                        .font(.system(size: metrics.titleFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("디자인 탐색부터 예약까지\n원스톱으로 연결해보세요.")
                        .font(.system(size: metrics.bodyFontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 4) {
                        Text("원스톱 시작하기")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: metrics.badgeFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.16))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                    )
                    .padding(.top, 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                }
                .padding(metrics.contentPadding)
            }
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.05 : 0.08), radius: 16, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
