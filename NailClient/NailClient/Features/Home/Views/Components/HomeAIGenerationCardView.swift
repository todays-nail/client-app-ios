//
//  HomeAIGenerationCardView.swift
//  NailClient
//

import SwiftUI

struct HomeAIGenerationCardView: View {
    let metrics: HomeLayoutMetrics
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
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
                        FeedDesignTokens.accent.opacity(0.52),
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
                        .background(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.22), in: Capsule())

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
                    .foregroundStyle(FeedDesignTokens.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, metrics.ctaVerticalPadding)
                    .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, metrics.aiCTATopPadding)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                }
                .padding(.top, metrics.contentPadding)
                .padding(.trailing, metrics.contentPadding)
                .padding(.bottom, metrics.contentPadding)
                .padding(.leading, metrics.aiContentLeadingPadding)
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
