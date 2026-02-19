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
    @State private var regionHeaderFrame: CGRect = .zero
    @StateObject private var regionPickerViewModel = RegionPickerViewModel()
    @State private var regionPickerMode: RegionPickerViewModel.ActionMode = .replaceCurrent
    @State private var isRegionPickerSheetPresented: Bool = false

    private static let topAnchorID = "feed_top_anchor"
    private static let feedCoordinateSpaceName = "feed_coordinate_space"
    private static let neighborhoodMenuWidth: CGFloat = 244

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
                        if appViewModel.isAIDesignSelectionInProgress {
                            designSelectionGuideBadge
                                .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                                .padding(.top, 10)
                                .padding(.bottom, 6)
                        }

                        FeedPromoBannerSectionView()
                            .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                            .padding(.top, 0)
                            .padding(.bottom, FeedDesignTokens.bannerToChipExtraSpacing)

                        Section {
                            if viewModel.isLoading && viewModel.filteredItems.isEmpty {
                                FeedListSkeletonView()
                                    .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                                    .padding(.top, FeedDesignTokens.chipToFeedSpacing)
                            } else if viewModel.filteredItems.isEmpty {
                                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                                    feedErrorState(message: errorMessage)
                                        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                                        .padding(.top, FeedDesignTokens.chipToFeedSpacing)
                                } else if viewModel.hasLoadedAtLeastOnce {
                                    feedEmptyState(
                                        title: "조건에 맞는 피드가 없어요",
                                        message: "스타일이나 일정을 바꿔 다시 확인해 주세요."
                                    )
                                    .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                                    .padding(.top, FeedDesignTokens.chipToFeedSpacing)
                                } else {
                                    FeedListSkeletonView()
                                        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                                        .padding(.top, FeedDesignTokens.chipToFeedSpacing)
                                }
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
                                .padding(.horizontal, FeedDesignTokens.horizontalPadding)
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
            .coordinateSpace(name: Self.feedCoordinateSpaceName)
            .background(FeedDesignTokens.screenBackground.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                headerView
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    errorBar(message: errorMessage)
                }
            }
            .overlay {
                neighborhoodMenuOverlay
            }
            .onPreferenceChange(FeedRegionHeaderFramePreferenceKey.self) { newFrame in
                regionHeaderFrame = newFrame
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
            .sheet(isPresented: $isRegionPickerSheetPresented) {
                RegionPickerSheetView(
                    viewModel: regionPickerViewModel,
                    mode: regionPickerMode,
                    service: appViewModel,
                    onClose: {
                        isRegionPickerSheetPresented = false
                    },
                    onSelectionCommitted: { result in
                        if regionPickerMode == .replaceCurrent {
                            applyRegionSelectionResult(result)
                        } else {
                            regionPickerViewModel.syncFromStore()
                        }
                        isRegionPickerSheetPresented = false
                    }
                )
                .interactiveDismissDisabled(regionPickerMode == .replaceCurrent && regionPickerViewModel.currentRegionID == nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(isPresented: $isShopSearchPresented) {
                ShopSearchView()
                    .environmentObject(appViewModel)
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
                await regionPickerViewModel.loadIfNeeded(service: appViewModel)
                regionPickerViewModel.syncFromStore()

                if let currentRegionID = regionPickerViewModel.currentRegionID,
                   let path = regionPickerViewModel.pathToRegion(currentRegionID),
                   let leaf = path.last {
                    let label = path.map(\.name).joined(separator: " ")
                    viewModel.applyExternalRegionSelection(
                        serviceRegionID: leaf.serviceScopeID,
                        displayLabel: label
                    )
                    await viewModel.loadInitialFeedIfNeeded()
                } else {
                    presentRegionPicker(mode: .replaceCurrent)
                }
            }
        }
    }

    private func errorBar(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text("피드 조회 실패")
                .appTypography(size: 13, weight: .semibold)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button("재시도") {
                Task {
                    await viewModel.loadInitialFeed(force: true)
                }
            }
            .appTypography(size: 13, weight: .bold)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
        .padding(.vertical, 11)
        .background(Color.black.opacity(0.78))
        .accessibilityLabel("피드 조회 실패. 재시도 버튼")
        .accessibilityHint(message)
    }

    private func feedErrorState(message: String) -> some View {
        feedEmptyState(
            title: "피드를 불러오지 못했어요",
            message: message,
            buttonTitle: "다시 시도"
        ) {
            Task {
                await viewModel.loadInitialFeed(force: true)
            }
        }
    }

    private func feedEmptyState(
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .appTypography(size: 22, weight: .semibold)
                .foregroundStyle(FeedDesignTokens.accent)

            Text(title)
                .appTypography(size: 16, weight: .bold)
                .foregroundStyle(FeedDesignTokens.primaryText)

            Text(message)
                .appTypography(size: 13, weight: .medium)
                .foregroundStyle(FeedDesignTokens.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .appTypography(size: 13, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FeedDesignTokens.detailCardBackground)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(FeedDesignTokens.chipBorder, lineWidth: 1)
                            )
                    )
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FeedDesignTokens.detailCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(FeedDesignTokens.chipBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
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
                Text(regionPickerViewModel.currentRegionLabel)
                    .appTypography(size: 19, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .lineLimit(1)
                Image(systemName: viewModel.isNeighborhoodMenuPresented ? "chevron.up" : "chevron.down")
                    .appTypography(size: 12, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.accent)
            }
            .contentShape(Rectangle())
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FeedRegionHeaderFramePreferenceKey.self,
                        value: proxy.frame(in: .named(Self.feedCoordinateSpaceName))
                    )
                }
            )
            .onTapGesture {
                viewModel.toggleNeighborhoodMenu()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("지역 선택")
            .accessibilityIdentifier("feed.region.header")

            Spacer(minLength: 12)

            Button {
                viewModel.dismissNeighborhoodMenu()
                isShopSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .appTypography(size: 19, weight: .semibold)
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

    private var designSelectionGuideBadge: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .appTypography(size: 14, weight: .bold)
                .foregroundStyle(FeedDesignTokens.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("피드에서 디자인 선택 중")
                    .appTypography(size: 14, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.primaryText)
                Text("상세 화면에서 ‘이 디자인 선택하기’를 누르면 AI 화면으로 돌아가요.")
                    .appTypography(size: 12, weight: .medium)
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button("취소") {
                appViewModel.cancelAIDesignSelection()
            }
            .appTypography(size: 12, weight: .semibold)
            .foregroundStyle(FeedDesignTokens.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(FeedDesignTokens.detailCardBackground)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(FeedDesignTokens.chipBorder, lineWidth: 1)
                    )
            )
            .buttonStyle(.plain)
            .accessibilityLabel("디자인 선택 모드 취소")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FeedDesignTokens.detailCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FeedDesignTokens.chipBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("피드에서 디자인 선택 중. 상세 화면에서 이 디자인 선택하기를 누르면 AI 화면으로 돌아갑니다.")
    }

    @ViewBuilder
    private var neighborhoodMenuOverlay: some View {
        if viewModel.isNeighborhoodMenuPresented {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.44)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.dismissNeighborhoodMenu()
                        }

                    FeedNeighborhoodDropdownMenuView(
                        currentRegionTitle: regionPickerViewModel.currentRegionLabel,
                        recentRegionTitle: regionPickerViewModel.recentRegionLabel,
                        onTapCurrentRegion: {
                            viewModel.dismissNeighborhoodMenu()
                        },
                        onTapRecentRegion: {
                            if let result = regionPickerViewModel.switchToRecentAsCurrent() {
                                applyRegionSelectionResult(result)
                            }
                            viewModel.dismissNeighborhoodMenu()
                        },
                        onTapAddRegion: {
                            presentRegionPicker(mode: .addRecent)
                        },
                        onTapSelectRegion: {
                            presentRegionPicker(mode: .replaceCurrent)
                        }
                    )
                    .offset(
                        x: neighborhoodMenuOriginX(in: geometry),
                        y: neighborhoodMenuOriginY(in: geometry)
                    )
                }
            }
            .transition(.opacity)
        }
    }

    private func neighborhoodMenuOriginX(in geometry: GeometryProxy) -> CGFloat {
        let minX = FeedDesignTokens.horizontalPadding
        let maxX = max(
            minX,
            geometry.size.width - Self.neighborhoodMenuWidth - FeedDesignTokens.horizontalPadding
        )
        return min(max(regionHeaderFrame.minX, minX), maxX)
    }

    private func neighborhoodMenuOriginY(in geometry: GeometryProxy) -> CGFloat {
        if regionHeaderFrame.maxY > 0 {
            return regionHeaderFrame.maxY + 6
        }
        return geometry.safeAreaInsets.top + 52
    }

    private func presentRegionPicker(mode: RegionPickerViewModel.ActionMode) {
        viewModel.dismissNeighborhoodMenu()
        regionPickerMode = mode
        isRegionPickerSheetPresented = true
        Task {
            await regionPickerViewModel.loadIfNeeded(service: appViewModel)
        }
    }

    private func applyRegionSelectionResult(_ result: RegionPickerViewModel.SelectionResult) {
        viewModel.applyExternalRegionSelection(
            serviceRegionID: result.selectedServiceScopeID,
            displayLabel: result.selectedLabel
        )
        regionPickerViewModel.syncFromStore()
    }
}

private struct FeedRegionHeaderFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

#Preview("Scroll Test - 20 Items") {
    let baseItems = FeedMockData.feedItems
    let previewItems = (0..<20).map { index in
        let item = baseItems[index % baseItems.count]

        return FeedItem(
            imageName: item.imageName,
            likeCount: item.likeCount + index,
            isReservable: item.isReservable,
            isLiked: item.isLiked
        )
    }

    return FeedView(viewModel: FeedViewModel(items: previewItems))
}
