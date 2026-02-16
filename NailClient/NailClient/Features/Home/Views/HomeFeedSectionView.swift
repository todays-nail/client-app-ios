//
//  HomeFeedSectionView.swift
//  NailClient
//

import SwiftUI

struct HomeFeedSectionView: View {
    let items: [HomeFeedItem]
    let onToggleLike: (HomeFeedItem.ID) -> Void

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: HomeDesignTokens.feedGridSpacing),
            count: HomeDesignTokens.feedGridColumnCount
        )
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: HomeDesignTokens.feedGridSpacing) {
            ForEach(items) { item in
                feedCell(item)
            }
        }
    }

    private func feedCell(_ item: HomeFeedItem) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(HomeDesignTokens.feedItemAspectRatio, contentMode: .fit)
            .overlay {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    onToggleLike(item.id)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(item.isLiked ? Color.red : Color.white)
                        Text("\(item.likeCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isLiked ? "좋아요 취소" : "좋아요")
                .accessibilityValue("\(item.likeCount)")
                .padding(HomeDesignTokens.feedBadgePadding)
            }
    }
}
