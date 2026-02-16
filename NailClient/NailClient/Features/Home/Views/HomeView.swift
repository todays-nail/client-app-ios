//
//  HomeView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: HomeDesignTokens.feedGridSpacing),
            count: HomeDesignTokens.feedGridColumnCount
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HomeDesignTokens.sectionSpacing) {
                    promoBanner
                    categoryChips
                    nailGrid
                }
                .padding(.horizontal, HomeDesignTokens.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .background(HomeDesignTokens.screenBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                    } label: {
                        HStack(spacing: 6) {
                            Text("서울 강남")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(HomeDesignTokens.primaryText)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(HomeDesignTokens.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(HomeDesignTokens.primaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("알림")
                }
            }
        }
    }

    private var promoBanner: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: HomeDesignTokens.bannerCornerRadius, style: .continuous)
                    .fill(HomeDesignTokens.bannerBackground)

                Image(HomeMockData.promoImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 0.45, height: height)
                    .clipped()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                BannerDiagonalOverlayShape()
                    .fill(HomeDesignTokens.bannerOverlay)
                    .opacity(0.72)
                    .frame(width: width * 0.62, height: height)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 6) {
                    Text(HomeMockData.promoTitle)
                        .font(.system(size: 24, weight: .heavy))
                        .lineSpacing(2)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(HomeMockData.promoDescription)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                    } label: {
                        Text("시작하기")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(HomeDesignTokens.accent)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .frame(width: width * 0.60, alignment: .leading)
                .padding(.leading, 20)
                .padding(.vertical, 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: HomeDesignTokens.bannerCornerRadius, style: .continuous))
        }
        .frame(height: 160)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.categories, id: \.self) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button {
                        viewModel.selectCategory(category)
                    } label: {
                        Text(category)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? HomeDesignTokens.selectedChipText : HomeDesignTokens.unselectedChipText
                            )
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? HomeDesignTokens.selectedChipBackground : HomeDesignTokens.unselectedChipBackground)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(isSelected ? .clear : HomeDesignTokens.chipBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var nailGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: HomeDesignTokens.feedGridSpacing) {
            ForEach(viewModel.items) { item in
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

private struct BannerDiagonalOverlayShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.22, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

#Preview {
    HomeView()
}
