//
//  ProfileTopSummarySectionView.swift
//  NailClient
//

import SwiftUI

struct ProfileTopSummarySectionView: View {
    let display: ProfileViewModel.ProfileHeaderDisplay
    let summary: ProfileViewModel.StyleInsightSummary
    let onTapEdit: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: ProfileDesignTokens.topSummaryHorizontalSpacing) {
                ProfileHeroSectionView(display: display, onTapEdit: onTapEdit)
                    .frame(width: ProfileDesignTokens.topSummaryLeftWidth)

                ProfileStyleAnalysisCardView(summary: summary)
            }

            VStack(spacing: ProfileDesignTokens.topSummaryHorizontalSpacing) {
                ProfileHeroSectionView(display: display, onTapEdit: onTapEdit)
                ProfileStyleAnalysisCardView(summary: summary)
            }
        }
    }
}
