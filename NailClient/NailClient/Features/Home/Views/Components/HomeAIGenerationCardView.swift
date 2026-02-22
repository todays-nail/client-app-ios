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
                        .black.opacity(0.80),
                        .black.opacity(0.50),
                        .black.opacity(0.22)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                RadialGradient(
                    colors: [
                        FeedDesignTokens.accent.opacity(0.42),
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
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.20))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
                        )

                    Spacer()

                    Text("고민말고 AI로 오늘 네일")
                        .font(.system(size: metrics.titleFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text("원하는 무드와 디자인을 입력하면\n내 손에 AI로 빠르게 시뮬레이션해요.")
                        .font(.system(size: metrics.bodyFontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.top, 4)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Text("손 사진 업로드 · AI 적용 미리보기")
                        .font(.system(size: metrics.badgeFontSize, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
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
                    .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 8, x: 0, y: 4)
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
