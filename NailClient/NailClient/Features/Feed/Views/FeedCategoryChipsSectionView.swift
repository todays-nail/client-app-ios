//
//  FeedCategoryChipsSectionView.swift
//  NailClient
//

import SwiftUI

struct FeedCategoryChipsSectionView: View {
    let categories: [String]
    let selectedCategory: String
    let selectedStyles: [FeedViewModel.StyleOption]
    let styleCategoryName: String
    let reservationSummaryText: String?
    let scheduleCategoryName: String
    let onSelectCategory: (String) -> Void
    let onTapStyleCategory: () -> Void
    let onRemoveStyle: (FeedViewModel.StyleOption) -> Void
    let onTapScheduleCategory: () -> Void
    let onClearScheduleSelection: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(headerChipItems) { chipItem in
                    chipView(chipItem)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var headerChipItems: [FeedChipItem] {
        FeedChipItemBuilder.makeHeaderChipItems(
            categories: categories,
            selectedCategory: selectedCategory,
            selectedStyles: selectedStyles,
            styleCategoryName: styleCategoryName,
            scheduleCategoryName: scheduleCategoryName,
            reservationSummaryText: reservationSummaryText
        )
    }

    @ViewBuilder
    private func chipView(_ chipItem: FeedChipItem) -> some View {
        switch chipItem {
        case let .category(name, isSelected):
            categoryChip(name, isSelected: isSelected)
        case let .styleSelected(style):
            selectedStyleChip(style)
        case .addStyle:
            addStyleChip
        case let .reservationSummary(text):
            reservationSummaryChip(text)
        }
    }

    private func categoryChip(_ category: String, isSelected: Bool) -> some View {
        BaseChipContainer(style: FeedChipPreset.category(selected: isSelected).style) {
            if category == styleCategoryName {
                onTapStyleCategory()
            } else if category == scheduleCategoryName {
                onTapScheduleCategory()
            } else {
                onSelectCategory(category)
            }
        } content: {
            Text(category)
        }
    }

    private func selectedStyleChip(_ style: FeedViewModel.StyleOption) -> some View {
        BaseChipContainer(
            style: FeedChipPreset.removableAccent.style,
            accessibilityLabel: "\(style.displayName) 제거"
        ) {
            onRemoveStyle(style)
        } content: {
            HStack(spacing: 6) {
                Text(style.displayName)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
        }
    }

    private var addStyleChip: some View {
        BaseChipContainer(
            style: FeedChipPreset.addStyle.style,
            accessibilityLabel: "스타일 추가"
        ) {
            onTapStyleCategory()
        } content: {
            Text("+ 스타일")
        }
    }

    private func reservationSummaryChip(_ text: String) -> some View {
        BaseChipContainer(
            style: FeedChipPreset.removableAccent.style,
            accessibilityLabel: "예약 일정 \(text) 제거"
        ) {
            onClearScheduleSelection()
        } content: {
            HStack(spacing: 6) {
                Text(text)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
        }
    }
}
