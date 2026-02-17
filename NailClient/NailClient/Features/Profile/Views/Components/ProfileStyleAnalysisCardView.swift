//
//  ProfileStyleAnalysisCardView.swift
//  NailClient
//

import SwiftUI

struct ProfileStyleAnalysisCardView: View {
    let summary: ProfileViewModel.StyleInsightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("나의 스타일 분석")
                .font(.system(ProfileDesignTokens.cardTitleStyle, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)

            Text(summary.subtitle)
                .font(.system(ProfileDesignTokens.cardSubtitleStyle, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            HStack(alignment: .center, spacing: 14) {
                ringChart(ratio: summary.primaryRatio, rankText: summary.rankText)
                    .frame(
                        width: ProfileDesignTokens.styleCardRingSize,
                        height: ProfileDesignTokens.styleCardRingSize
                    )

                VStack(alignment: .leading, spacing: ProfileDesignTokens.styleCardRowSpacing) {
                    ForEach(summary.items) { item in
                        styleInsightRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(ProfileDesignTokens.styleCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignTokens.cardCornerRadius, style: .continuous)
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileDesignTokens.cardCornerRadius, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
        )
    }

    private func ringChart(ratio: Double, rankText: String) -> some View {
        let clampedRatio = max(0, min(1, ratio))

        return ZStack {
            Circle()
                .stroke(ProfileDesignTokens.styleProgressTrack, lineWidth: ProfileDesignTokens.styleCardRingLineWidth)

            Circle()
                .trim(from: 0, to: clampedRatio)
                .stroke(
                    ProfileDesignTokens.accent,
                    style: StrokeStyle(lineWidth: ProfileDesignTokens.styleCardRingLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(rankText)
                .font(.system(ProfileDesignTokens.ringCenterStyle, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)
        }
    }

    private func styleInsightRow(_ item: ProfileViewModel.StyleInsightItem) -> some View {
        let foregroundColor = item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.mutedAccent
        let textColor = item.emphasized ? ProfileDesignTokens.primaryText : ProfileDesignTokens.secondaryText

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(foregroundColor)
                    .frame(width: 7, height: 7)

                Text(item.tag)
                    .font(.system(ProfileDesignTokens.insightItemStyle, weight: .semibold))
                    .foregroundStyle(textColor)

                Spacer(minLength: 6)

                Text(item.percentageText)
                    .font(.system(ProfileDesignTokens.insightItemStyle, weight: .bold))
                    .foregroundStyle(item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.secondaryText)
            }

            GeometryReader { proxy in
                let fullWidth = proxy.size.width
                Capsule()
                    .fill(ProfileDesignTokens.styleProgressTrack)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(foregroundColor)
                            .frame(width: max(0, fullWidth * item.ratio))
                    }
            }
            .frame(height: ProfileDesignTokens.styleProgressBarHeight)
        }
    }
}
