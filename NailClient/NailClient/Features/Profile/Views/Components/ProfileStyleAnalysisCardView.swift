//
//  ProfileStyleAnalysisCardView.swift
//  NailClient
//

import SwiftUI

struct ProfileStyleAnalysisCardView: View {
    let summary: ProfileViewModel.StyleInsightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileDesignTokens.compactStyleItemSpacing) {
            Text("나의 스타일 분석")
                .font(.system(ProfileDesignTokens.sectionTitleStyle, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.primaryText)

            HStack(alignment: .center, spacing: 12) {
                ringChart(ratio: summary.primaryRatio, rankText: summary.rankText)
                    .frame(
                        width: ProfileDesignTokens.compactStyleRingSize,
                        height: ProfileDesignTokens.compactStyleRingSize
                    )

                VStack(alignment: .leading, spacing: ProfileDesignTokens.compactStyleItemSpacing) {
                    ForEach(summary.items) { item in
                        styleInsightRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(ProfileDesignTokens.compactStyleCardPadding)
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
                .stroke(ProfileDesignTokens.mutedAccent.opacity(0.35), lineWidth: 8)

            Circle()
                .trim(from: 0, to: clampedRatio)
                .stroke(
                    ProfileDesignTokens.accent,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(rankText)
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)
        }
    }

    private func styleInsightRow(_ item: ProfileViewModel.StyleInsightItem) -> some View {
        let foregroundColor = item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.mutedAccent
        let textColor = item.emphasized ? ProfileDesignTokens.primaryText : ProfileDesignTokens.secondaryText

        return HStack(spacing: 6) {
            Circle()
                .fill(foregroundColor)
                .frame(width: 7, height: 7)

            Text(item.tag)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(textColor)

            Spacer(minLength: 4)

            Text(item.percentageText)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.secondaryText)
        }
    }
}
