//
//  ProfileStyleAnalysisCardView.swift
//  NailClient
//

import SwiftUI

struct ProfileStyleAnalysisCardView: View {
    let isLoading: Bool
    let summary: ProfileViewModel.StyleInsightSummary?
    let recommendationTags: [String]
    let isEmpty: Bool
    let emptySuggestionTitle: String
    let errorMessage: String?
    let onTapEmptySuggestion: () -> Void
    let onRetry: () -> Void

    init(
        isLoading: Bool,
        summary: ProfileViewModel.StyleInsightSummary?,
        recommendationTags: [String],
        isEmpty: Bool,
        emptySuggestionTitle: String,
        errorMessage: String?,
        onTapEmptySuggestion: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.summary = summary
        self.recommendationTags = recommendationTags
        self.isEmpty = isEmpty
        self.emptySuggestionTitle = emptySuggestionTitle
        self.errorMessage = errorMessage
        self.onTapEmptySuggestion = onTapEmptySuggestion
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("나의 스타일 분석")
                .font(.system(ProfileDesignTokens.cardTitleStyle, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)

            if isLoading {
                loadingContent
            } else if let summary {
                summaryContent(summary)
            } else if isEmpty {
                emptyContent
            } else {
                errorContent
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

    private var loadingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("분석 데이터를 불러오는 중이에요")
                .font(.system(ProfileDesignTokens.cardSubtitleStyle, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            ProgressView()
                .tint(ProfileDesignTokens.accent)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ProfileDesignTokens.styleProgressTrack)
                .frame(height: 10)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ProfileDesignTokens.styleProgressTrack)
                .frame(width: 140, height: 10)
        }
    }

    private func summaryContent(_ summary: ProfileViewModel.StyleInsightSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if !recommendationTags.isEmpty {
                recommendationTagSection
            }
        }
    }

    private var recommendationTagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("추천 태그")
                .appTypography(size: 12, weight: .semibold)
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recommendationTags, id: \.self) { tag in
                        Text(tag)
                            .appTypography(size: 12, weight: .semibold)
                            .foregroundStyle(ProfileDesignTokens.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ProfileDesignTokens.styleProgressTrack, in: Capsule())
                    }
                }
            }
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("찜/시술 데이터가 부족해요")
                .font(.system(ProfileDesignTokens.cardSubtitleStyle, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            Button(emptySuggestionTitle) {
                onTapEmptySuggestion()
            }
            .appTypography(size: 13, weight: .semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(ProfileDesignTokens.accent)
            )
        }
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(errorMessage ?? "스타일 분석을 불러오지 못했어요")
                .font(.system(ProfileDesignTokens.cardSubtitleStyle, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            Button("다시 시도") {
                onRetry()
            }
            .appTypography(size: 13, weight: .bold)
            .foregroundStyle(ProfileDesignTokens.accent)
        }
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
