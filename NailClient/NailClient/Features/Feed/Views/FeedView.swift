//
//  FeedView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

@MainActor
struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    init() {
        _viewModel = StateObject(wrappedValue: FeedViewModel())
    }

    init(viewModel: FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    FeedPromoBannerSectionView()
                        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                        .padding(.top, 0)
                        .padding(.bottom, FeedDesignTokens.bannerToChipExtraSpacing)

                    Section {
                        FeedSectionView(
                            items: viewModel.filteredItems,
                            onToggleLike: viewModel.toggleLike
                        )
                            .padding(.top, FeedDesignTokens.chipToFeedSpacing)
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
            .background(FeedDesignTokens.screenBackground.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                headerView
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
            .alert("최대 3개까지 선택", isPresented: $viewModel.showMaxStyleAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("스타일은 최대 3개까지 선택할 수 있어요.")
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Text("서울 강남")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.accent)
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
                .foregroundStyle(FeedDesignTokens.primaryText)
                .padding(4)
                .contentShape(Rectangle())
                .onTapGesture {
                }
                .accessibilityLabel("알림")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 0)
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
