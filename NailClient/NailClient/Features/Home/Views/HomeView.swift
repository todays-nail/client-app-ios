//
//  HomeView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

@MainActor
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    HomePromoBannerSectionView()
                        .padding(.horizontal, HomeDesignTokens.horizontalPadding)
                        .padding(.top, 0)
                        .padding(.bottom, HomeDesignTokens.bannerToChipExtraSpacing)

                    Section {
                        HomeFeedSectionView(
                            items: viewModel.filteredItems,
                            onToggleLike: viewModel.toggleLike
                        )
                            .padding(.top, HomeDesignTokens.chipToFeedSpacing)
                    } header: {
                        HomeCategoryChipsSectionView(
                            categories: viewModel.categories,
                            selectedCategory: viewModel.selectedCategory,
                            onSelectCategory: viewModel.selectCategory
                        )
                        .padding(.horizontal, HomeDesignTokens.horizontalPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HomeDesignTokens.screenBackground)
                    }
                }
                .padding(.bottom, 12)
            }
            .background(HomeDesignTokens.screenBackground.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                headerView
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Text("서울 강남")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(HomeDesignTokens.primaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomeDesignTokens.accent)
            }
            .contentShape(Rectangle())
            .onTapGesture {
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("지역 선택")

            Spacer(minLength: 12)

            Image(systemName: "bell")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(HomeDesignTokens.primaryText)
                .padding(4)
                .contentShape(Rectangle())
                .onTapGesture {
                }
                .accessibilityLabel("알림")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, HomeDesignTokens.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(HomeDesignTokens.screenBackground)
    }
}

#Preview("Scroll Test - 20 Items") {
    let baseItems = HomeMockData.feedItems
    let previewItems = (0..<20).map { index in
        let item = baseItems[index % baseItems.count]

        return HomeFeedItem(
            imageName: item.imageName,
            likeCount: item.likeCount + index,
            shapeCategory: item.shapeCategory,
            isReservable: item.isReservable,
            isLiked: item.isLiked
        )
    }

    return HomeView(viewModel: HomeViewModel(items: previewItems))
}
