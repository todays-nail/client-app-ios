//
//  HomeView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: HomeDesignTokens.sectionSpacing) {
                        HomePromoBannerSectionView()
                            .padding(.bottom, HomeDesignTokens.bannerToChipExtraSpacing)
                        HomeCategoryChipsSectionView(
                            categories: viewModel.categories,
                            selectedCategory: viewModel.selectedCategory,
                            onSelectCategory: viewModel.selectCategory
                        )
                        .padding(.bottom, HomeDesignTokens.chipToFeedSpacing)
                    }
                    .padding(.horizontal, HomeDesignTokens.horizontalPadding)

                    HomeFeedSectionView(items: viewModel.items)
                }
                .padding(.top, 8)
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
        .padding(.bottom, 6)
        .background(HomeDesignTokens.screenBackground)
    }
}

#Preview {
    HomeView()
}
