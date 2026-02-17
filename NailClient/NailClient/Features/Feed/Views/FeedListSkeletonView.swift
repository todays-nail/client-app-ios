//
//  FeedListSkeletonView.swift
//  NailClient
//

import SwiftUI

struct FeedListSkeletonView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(FeedDesignTokens.accent)

            Text("피드를 불러오는 중")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FeedDesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .accessibilityLabel("피드를 불러오는 중")
    }
}

#Preview("피드 목록 로딩") {
    FeedListSkeletonView()
        .padding(.top, FeedDesignTokens.chipToFeedSpacing)
        .background(FeedDesignTokens.screenBackground)
}
