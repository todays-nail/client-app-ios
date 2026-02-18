//
//  ShopSearchView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct ShopSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ShopSearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
                .padding(.horizontal, ShopSearchDesignTokens.horizontalPadding)
                .padding(.vertical, 14)

            Divider()

            regionHeader
                .padding(.horizontal, ShopSearchDesignTokens.horizontalPadding)
                .padding(.vertical, 12)

            Divider()

            Group {
                if viewModel.isSearchMode {
                    searchContent
                } else {
                    discoveryContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, ShopSearchDesignTokens.horizontalPadding)
            .padding(.top, ShopSearchDesignTokens.sectionTopPadding)
            .padding(.bottom, 16)
        }
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "샵 이름 검색")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadDiscoveryIfNeeded()
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            Text("샵 검색")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(FeedDesignTokens.primaryText)

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .background(
                        Circle()
                            .fill(AppColorTokens.inputBackground)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
            .accessibilityHint("샵 검색 창 닫기")
        }
        .frame(minHeight: ShopSearchDesignTokens.headerHeight)
    }

    private var regionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(viewModel.currentRegionLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FeedDesignTokens.secondaryText)

            Spacer(minLength: 8)

            if viewModel.isDiscoverLoading && !viewModel.isSearchMode {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColorTokens.cardSubtleBackground)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("현재 지역")
    }

    @ViewBuilder
    private var searchContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            statusStateView(
                title: viewModel.state == .loading ? "검색 중..." : "샵 이름을 입력해 주세요",
                message: "샵 이름으로 빠르게 찾아보세요.",
                icon: "magnifyingglass",
                isLoading: viewModel.state == .loading
            )
        case .results:
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.items) { item in
                        NavigationLink {
                            ShopDetailView(shopID: item.id)
                        } label: {
                            searchResultRow(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
        case .empty:
            statusStateView(
                title: "검색 결과가 없어요",
                message: "다른 샵 이름으로 다시 검색해 보세요.",
                icon: "building.2"
            )
        case let .error(message):
            VStack(spacing: 14) {
                statusStateView(
                    title: "검색을 가져오지 못했어요",
                    message: message,
                    icon: "exclamationmark.triangle.fill"
                )

                Button("다시 시도") {
                    viewModel.retry()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var discoveryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recentSearchSection
                recommendationSection
            }
            .padding(.top, 2)
            .padding(.bottom, 4)
        }
    }

    private var recentSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 검색")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)

                Spacer(minLength: 8)

                if !viewModel.recentSearches.isEmpty {
                    Button("전체 삭제") {
                        viewModel.clearRecentSearches()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .accessibilityLabel("최근 검색어 전체 삭제")
                    .accessibilityHint("최근 검색어를 모두 삭제합니다")
                }
            }

            if viewModel.recentSearches.isEmpty {
                Text("최근 검색어가 없어요.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.recentSearches, id: \.self) { query in
                            recentSearchChip(query)
                        }
                    }
                }
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이런 샵은 어떠신가요?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FeedDesignTokens.primaryText)

            Text(viewModel.recommendationScope == .region ? "내 지역 인기 순" : "전국 인기 순")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FeedDesignTokens.secondaryText)

            if let discoveryErrorMessage = viewModel.discoveryErrorMessage, viewModel.recommendations.isEmpty {
                Text(discoveryErrorMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
            } else if viewModel.recommendations.isEmpty {
                Text("추천할 샵이 아직 없어요.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.recommendations) { item in
                        NavigationLink {
                            ShopDetailView(shopID: item.id)
                        } label: {
                            recommendationRow(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusStateView(
        title: String,
        message: String,
        icon: String,
        isLoading: Bool = false
    ) -> some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.accent)
            }

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FeedDesignTokens.primaryText)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(FeedDesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
        .padding(.horizontal, 24)
    }

    private func recentSearchChip(_ query: String) -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.applyRecentSearch(query)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FeedDesignTokens.secondaryText)
                    Text(query)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FeedDesignTokens.primaryText)
                        .lineLimit(1)
                }
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .padding(.trailing, 4)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Button {
                viewModel.removeRecentSearch(query)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FeedDesignTokens.secondaryText.opacity(0.75))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("최근 검색어 삭제")
            .accessibilityHint("\(query) 최근 검색어를 삭제합니다")
        }
        .padding(.horizontal, 6)
        .background(
            Capsule()
                .fill(AppColorTokens.chipBackground)
                .overlay {
                    Capsule()
                        .stroke(AppColorTokens.chipBorder, lineWidth: 1)
                }
        )
        .frame(minHeight: 44)
    }

    private func searchResultRow(for item: ShopSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .lineLimit(1)
                Text(item.address)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FeedDesignTokens.secondaryText)
        }
        .padding(12)
        .frame(minHeight: 68)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColorTokens.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColorTokens.borderSoft, lineWidth: 1)
                }
        )
        .fullRowTapTarget(alignment: .leading)
    }

    private func recommendationRow(for item: ShopRecommendation) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .lineLimit(1)
                Text(item.address)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Text("좋아요 \(item.likeCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(AppColorTokens.inputBackground)
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
            }
        }
        .padding(12)
        .frame(minHeight: 86)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColorTokens.cardSubtleBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColorTokens.borderSoft, lineWidth: 1)
                }
        )
        .fullRowTapTarget(alignment: .leading)
    }
}

private enum ShopSearchDesignTokens {
    static let horizontalPadding: CGFloat = 16
    static let sectionTopPadding: CGFloat = 12
    static let headerHeight: CGFloat = 40
}

#Preview {
    NavigationStack {
        ShopSearchView()
            .environmentObject(AppViewModel())
    }
}
