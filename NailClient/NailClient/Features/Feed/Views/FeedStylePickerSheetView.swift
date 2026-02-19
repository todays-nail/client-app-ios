//
//  FeedStylePickerSheetView.swift
//  NailClient
//

import SwiftUI

struct FeedStylePickerSheetView: View {
    let selectedStyles: [FeedViewModel.StyleOption]
    let maxSelectionCount: Int
    let onToggleStyle: (FeedViewModel.StyleOption) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .lastTextBaseline) {
                Text("스타일 선택")
                    .appTypography(size: 18, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.primaryText)

                Spacer()

                Text("\(selectedStyles.count)/\(maxSelectionCount)")
                    .appTypography(size: 13, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.accent)
            }

            Text("최대 \(maxSelectionCount)개까지 선택할 수 있어요")
                .appTypography(size: 13, weight: .medium)
                .foregroundStyle(FeedDesignTokens.unselectedChipText.opacity(0.75))

            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(FeedViewModel.StyleOption.allCases) { style in
                        styleChip(style)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            Button("완료") {
                onDone()
            }
            .appTypography(size: 16, weight: .bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(FeedDesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
            .accessibilityLabel("스타일 선택 완료")
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private func styleChip(_ style: FeedViewModel.StyleOption) -> some View {
        let isSelected = selectedStyles.contains(style)

        return BaseChipContainer(
            style: FeedChipPreset.stylePicker(selected: isSelected).style,
            accessibilityLabel: isSelected ? "\(style.displayName) 선택 해제" : "\(style.displayName) 선택"
        ) {
            onToggleStyle(style)
        } content: {
            Text(style.displayName)
        }
    }
}
