//
//  ProfileStyleAnalysisCardView.swift
//  NailClient
//

import SwiftUI

struct ProfileStyleAnalysisCardView: View {
    let summary: ProfileViewModel.StyleInsightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("나의 스타일 분석")
                        .font(.system(ProfileDesignTokens.cardTitleStyle, weight: .bold))
                        .foregroundStyle(ProfileDesignTokens.primaryText)

                    Text(summary.subtitle)
                        .font(.system(ProfileDesignTokens.cardSubtitleStyle, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.secondaryText)
                }

                Spacer(minLength: 10)

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ProfileDesignTokens.accent)
                    .frame(width: 54, height: 54)
                    .background(Color(hex: 0xFCE9E5), in: Circle())
            }

            HStack(spacing: 16) {
                ringChart(ratio: summary.primaryRatio, rankText: summary.rankText)
                    .frame(width: 120, height: 120)

                VStack(spacing: 14) {
                    ForEach(summary.items) { item in
                        styleInsightRow(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
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
                .stroke(ProfileDesignTokens.mutedAccent.opacity(0.35), lineWidth: 11)

            Circle()
                .trim(from: 0, to: clampedRatio)
                .stroke(
                    ProfileDesignTokens.accent,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(rankText)
                .font(.system(ProfileDesignTokens.ringCenterStyle, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)
        }
    }

    private func styleInsightRow(_ item: ProfileViewModel.StyleInsightItem) -> some View {
        let ratio = max(0, min(1, item.ratio))
        let foregroundColor = item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.mutedAccent
        let textColor = item.emphasized ? ProfileDesignTokens.primaryText : ProfileDesignTokens.secondaryText

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(foregroundColor)
                    .frame(width: 10, height: 10)

                Text(item.tag)
                    .font(.system(ProfileDesignTokens.insightItemStyle, weight: .semibold))
                    .foregroundStyle(textColor)

                Spacer(minLength: 8)

                Text(item.percentageText)
                    .font(.system(ProfileDesignTokens.insightItemStyle, weight: .semibold))
                    .foregroundStyle(item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.secondaryText)
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(ProfileDesignTokens.mutedAccent.opacity(0.35))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(foregroundColor)
                            .frame(width: proxy.size.width * ratio)
                    }
            }
            .frame(height: 10)
        }
    }
}
