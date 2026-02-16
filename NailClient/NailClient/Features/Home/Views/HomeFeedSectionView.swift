//
//  HomeFeedSectionView.swift
//  NailClient
//

import SwiftUI

struct HomeFeedSectionView: View {
    let items: [HomeFeedItem]

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
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(item.likeCount)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule(style: .continuous))
                .padding(HomeDesignTokens.feedBadgePadding)
            }
    }
}
