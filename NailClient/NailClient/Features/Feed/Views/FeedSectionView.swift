//
//  FeedSectionView.swift
//  NailClient
//

import SwiftUI

struct FeedSectionView: View {
    let items: [FeedItem]
    let onToggleLike: (FeedItem.ID) -> Void
    let onApplyLikeState: (FeedItem.ID, Bool, Int) -> Void
    let onItemAppear: (FeedItem.ID) -> Void

    init(
        items: [FeedItem],
        onToggleLike: @escaping (FeedItem.ID) -> Void,
        onApplyLikeState: @escaping (FeedItem.ID, Bool, Int) -> Void = { _, _, _ in },
        onItemAppear: @escaping (FeedItem.ID) -> Void = { _ in }
    ) {
        self.items = items
        self.onToggleLike = onToggleLike
        self.onApplyLikeState = onApplyLikeState
        self.onItemAppear = onItemAppear
    }

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
                    .onAppear {
                        onItemAppear(item.id)
                    }
            }
        }
    }

    private func feedCell(_ item: FeedItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationLink {
                FeedDetailView(item: item, onLikeStateChange: onApplyLikeState)
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .aspectRatio(FeedDesignTokens.feedItemAspectRatio, contentMode: .fit)
                    .overlay {
                        feedThumbnail(item)
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

    @ViewBuilder
    private func feedThumbnail(_ item: FeedItem) -> some View {
        if let url = item.thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                case .failure:
                    loadingThumbnail
                case .empty:
                    loadingThumbnail
                @unknown default:
                    loadingThumbnail
                }
            }
        } else {
            loadingThumbnail
        }
    }

    private var loadingThumbnail: some View {
        ProgressView()
            .tint(FeedDesignTokens.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FeedDesignTokens.detailPlaceholderBackground)
    }
}
