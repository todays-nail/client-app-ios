//
//  FeedView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

@MainActor
struct FeedView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: FeedViewModel
    @State private var didCorrectInitialScrollOffset: Bool = false
    @State private var isShopSearchPresented: Bool = false

    private static let topAnchorID = "feed_top_anchor"

    init() {
        _viewModel = StateObject(wrappedValue: FeedViewModel())
    }

    init(viewModel: FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.topAnchorID)

                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        FeedPromoBannerSectionView()
                            .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                            .padding(.top, 0)
                            .padding(.bottom, FeedDesignTokens.bannerToChipExtraSpacing)

                        Section {
                            if viewModel.isLoading && viewModel.filteredItems.isEmpty {
                                FeedListSkeletonView()
                                    .padding(.top, FeedDesignTokens.chipToFeedSpacing)
                            } else {
                                FeedSectionView(
                                    items: viewModel.filteredItems,
                                    onToggleLike: viewModel.toggleLike,
                                    onApplyLikeState: { itemID, isLiked, likeCount in
                                        viewModel.applyLikeState(for: itemID, isLiked: isLiked, likeCount: likeCount)
                                    },
                                    onItemAppear: { itemID in
                                        Task {
                                            await viewModel.loadMoreIfNeeded(currentItemID: itemID)
                                        }
                                    }
                                )
                                .padding(.top, FeedDesignTokens.chipToFeedSpacing)
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .tint(FeedDesignTokens.accent)
                                    .padding(.vertical, 16)
                            }
                        } header: {
                            FeedCategoryChipsSectionView(
                                categories: viewModel.categories,
                                selectedCategory: viewModel.selectedCategory,
                                selectedStyles: viewModel.selectedStyles,
                                styleCategoryName: viewModel.styleCategoryName,
                                reservationSummaryText: viewModel.reservationSummaryText,
                                scheduleCategoryName: viewModel.scheduleCategoryName,
                                onSelectCategory: viewModel.selectCategory,
                                onTapStyleCategory: viewModel.handleStyleCategoryTap,
                                onRemoveStyle: viewModel.removeStyle,
                                onTapScheduleCategory: viewModel.handleScheduleCategoryTap,
                                onClearScheduleSelection: viewModel.clearScheduleSelection
                            )
                            .padding(.top, FeedDesignTokens.headerToContentSpacing)
                            .padding(.bottom, FeedDesignTokens.chipHeaderBottomSpacing)
                            .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FeedDesignTokens.screenBackground)
                            .zIndex(1)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .onAppear {
                    guard !didCorrectInitialScrollOffset else { return }
                    didCorrectInitialScrollOffset = true

                    Task { @MainActor in
                        await Task.yield()
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            proxy.scrollTo(Self.topAnchorID, anchor: .top)
                        }
                    }
                }
            }
            .background(FeedDesignTokens.screenBackground.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                headerView
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    errorBar(message: errorMessage)
                }
            }
            .sheet(isPresented: $viewModel.isStylePickerPresented) {
                FeedStylePickerSheetView(
                    selectedStyles: viewModel.selectedStyles,
                    maxSelectionCount: viewModel.maxStyleSelectionCount,
                    onToggleStyle: viewModel.toggleStyle,
                    onDone: { viewModel.isStylePickerPresented = false }
                )
                .presentationDetents([.height(350), .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $viewModel.isSchedulePickerPresented) {
                FeedSchedulePickerSheetView(
                    dateOptions: viewModel.reservationDateOptions,
                    selectedDate: viewModel.selectedReservationDate,
                    timeSlots: viewModel.reservationTimeSlots,
                    selectedStartTime: viewModel.selectedStartTime,
                    selectedEndTime: viewModel.selectedEndTime,
                    onSelectDate: viewModel.selectReservationDate,
                    onUpdateStartTime: viewModel.updateStartTime,
                    onUpdateEndTime: viewModel.updateEndTime,
                    onDone: viewModel.applyScheduleSelectionAndActivateCategory
                )
                .presentationDetents([.height(FeedDesignTokens.scheduleSheetHeight), .medium])
                .presentationDragIndicator(.visible)
                .alert("시간 선택 확인", isPresented: $viewModel.showInvalidScheduleAlert) {
                    Button("확인", role: .cancel) { }
                } message: {
                    Text("종료 시간은 시작 시간보다 늦어야 해요.")
                }
            }
            .fullScreenCover(isPresented: $viewModel.isRegionPickerPresented) {
                FeedRegionSelectionView(
                    cities: viewModel.cities,
                    districtsByCityID: viewModel.districtsByCityID,
                    selectedCity: viewModel.selectedCity,
                    selectedDistrict: viewModel.selectedDistrict,
                    isLoading: viewModel.isRegionLoading,
                    onClose: {
                        viewModel.isRegionPickerPresented = false
                    },
                    onDone: { selectedCity, selectedDistrict in
                        if let selectedDistrict {
                            if let selectedCity {
                                viewModel.selectCity(selectedCity)
                            } else if let parentID = selectedDistrict.parentID,
                                      let matchedCity = viewModel.cities.first(where: { $0.id == parentID }) {
                                viewModel.selectCity(matchedCity)
                            } else {
                                viewModel.selectAllRegion()
                            }
                            viewModel.selectDistrict(selectedDistrict)
                        } else if let selectedCity {
                            viewModel.selectCity(selectedCity)
                        } else {
                            viewModel.selectAllRegion()
                        }
                        viewModel.applyRegionSelection()
                    }
                )
            }
            .sheet(isPresented: $isShopSearchPresented) {
                ShopSearchView()
                    .environmentObject(appViewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(22)
            }
            .alert("최대 3개까지 선택", isPresented: $viewModel.showMaxStyleAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("스타일은 최대 3개까지 선택할 수 있어요.")
            }
            .alert("좋아요 반영 실패", isPresented: likeErrorAlertBinding) {
                Button("확인", role: .cancel) {
                    viewModel.likeErrorMessage = nil
                }
            } message: {
                Text(viewModel.likeErrorMessage ?? "좋아요 반영에 실패했어요.")
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                viewModel.bind(service: appViewModel)
                await viewModel.loadInitialFeedIfNeeded()
            }
        }
    }

    private func errorBar(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text("피드 조회 실패")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button("재시도") {
                Task {
                    await viewModel.loadInitialFeed(force: true)
                }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
        .padding(.vertical, 11)
        .background(Color.black.opacity(0.78))
        .accessibilityLabel("피드 조회 실패. 재시도 버튼")
        .accessibilityHint(message)
    }

    private var likeErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { (viewModel.likeErrorMessage?.isEmpty == false) },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.likeErrorMessage = nil
                }
            }
        )
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Text(viewModel.regionHeaderText)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.accent)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.presentRegionPicker()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("지역 선택")

            Spacer(minLength: 12)

            Button {
                isShopSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("샵 검색")
            .accessibilityHint("샵 이름으로 검색 화면 열기")
        }
        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(FeedDesignTokens.screenBackground)
    }
}

#Preview("Scroll Test - 20 Items") {
    let baseItems = FeedMockData.feedItems
    let previewItems = (0..<20).map { index in
        let item = baseItems[index % baseItems.count]

        return FeedItem(
            imageName: item.imageName,
            likeCount: item.likeCount + index,
            shapeCategory: item.shapeCategory,
            isReservable: item.isReservable,
            isLiked: item.isLiked
        )
    }

    return FeedView(viewModel: FeedViewModel(items: previewItems))
}
