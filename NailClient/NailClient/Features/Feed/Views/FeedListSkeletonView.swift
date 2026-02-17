//
//  FeedListSkeletonView.swift
//  NailClient
//

import SwiftUI

struct FeedListSkeletonView: View {
    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: FeedDesignTokens.feedGridSpacing),
            count: FeedDesignTokens.feedGridColumnCount
        )
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: FeedDesignTokens.feedGridSpacing) {
            ForEach(0..<FeedDesignTokens.feedListSkeletonItemCount, id: \.self) { _ in
                skeletonCell
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("피드를 불러오는 중")
    }

    private var skeletonCell: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(FeedDesignTokens.feedItemAspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    ZStack(alignment: .bottomTrailing) {
                        SkeletonBlock(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            cornerRadius: 0
                        )

                        SkeletonBlock(width: 44, height: 22, shapeStyle: .capsule)
                            .padding(FeedDesignTokens.feedBadgePadding)
                    }
                }
            }
    }
}

#Preview {
    FeedListSkeletonView()
        .padding(.top, FeedDesignTokens.chipToFeedSpacing)
}
