//
//  FeedSectionView.swift
//  NailClient
//

import SwiftUI

struct FeedSectionView: View {
    let items: [FeedItem]
    let onToggleLike: (FeedItem.ID) -> Void

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: FeedDesignTokens.feedGridSpacing),
            count: FeedDesignTokens.feedGridColumnCount
        )
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: FeedDesignTokens.feedGridSpacing) {
            ForEach(items) { item in
                feedCell(item)
            }
        }
    }

    private func feedCell(_ item: FeedItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationLink {
                FeedDetailView(item: item) {
                    onToggleLike(item.id)
                }
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(FeedDesignTokens.feedItemAspectRatio, contentMode: .fit)
                    .overlay {
                        Image(item.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    }
            }
            .buttonStyle(.plain)

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
            .padding(FeedDesignTokens.feedBadgePadding)
        }
    }
}
