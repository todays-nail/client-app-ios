//
//  HomeCategoryChipsSectionView.swift
//  NailClient
//

import SwiftUI

struct HomeCategoryChipsSectionView: View {
    let categories: [String]
    let selectedCategory: String
    let selectedStyles: [HomeViewModel.StyleOption]
    let styleCategoryName: String
    let reservationSummaryText: String?
    let scheduleCategoryName: String
    let onSelectCategory: (String) -> Void
    let onTapStyleCategory: () -> Void
    let onRemoveStyle: (HomeViewModel.StyleOption) -> Void
    let onTapScheduleCategory: () -> Void
    let onClearScheduleSelection: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    if category == styleCategoryName && selectedStyles.isEmpty == false {
                        ForEach(selectedStyles) { style in
                            selectedStyleChip(style)
                        }
                        addStyleChip
                    } else {
                        categoryChip(category)
                    }
                }

                if let reservationSummaryText, reservationSummaryText.isEmpty == false {
                    reservationSummaryChip(reservationSummaryText)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func categoryChip(_ category: String) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            if category == styleCategoryName {
                onTapStyleCategory()
            } else if category == scheduleCategoryName {
                onTapScheduleCategory()
            } else {
                onSelectCategory(category)
            }
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

    private func selectedStyleChip(_ style: HomeViewModel.StyleOption) -> some View {
        Button {
            onRemoveStyle(style)
        } label: {
            HStack(spacing: 6) {
                Text(style.displayName)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(HomeDesignTokens.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(HomeDesignTokens.accent.opacity(0.38), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.displayName) 제거")
    }

    private var addStyleChip: some View {
        Button {
            onTapStyleCategory()
        } label: {
            Text("+ 스타일")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeDesignTokens.unselectedChipText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(HomeDesignTokens.unselectedChipBackground)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(HomeDesignTokens.chipBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("스타일 추가")
    }

    private func reservationSummaryChip(_ text: String) -> some View {
        Button {
            onClearScheduleSelection()
        } label: {
            HStack(spacing: 6) {
                Text(text)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(HomeDesignTokens.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(HomeDesignTokens.accent.opacity(0.38), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("예약 일정 \(text) 제거")
    }
}
