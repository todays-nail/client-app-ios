//
//  HomeStylePickerSheetView.swift
//  NailClient
//

import SwiftUI

struct HomeStylePickerSheetView: View {
    let selectedStyles: [HomeViewModel.StyleOption]
    let maxSelectionCount: Int
    let onToggleStyle: (HomeViewModel.StyleOption) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .lastTextBaseline) {
                Text("스타일 선택")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(HomeDesignTokens.primaryText)

                Spacer()

                Text("\(selectedStyles.count)/\(maxSelectionCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HomeDesignTokens.accent)
            }

            Text("최대 \(maxSelectionCount)개까지 선택할 수 있어요")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HomeDesignTokens.unselectedChipText.opacity(0.75))

            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(HomeViewModel.StyleOption.allCases) { style in
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
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(HomeDesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
            .accessibilityLabel("스타일 선택 완료")
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private func styleChip(_ style: HomeViewModel.StyleOption) -> some View {
        let isSelected = selectedStyles.contains(style)

        return Button {
            onToggleStyle(style)
        } label: {
            Text(style.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? HomeDesignTokens.selectedChipText : HomeDesignTokens.unselectedChipText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
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
        .accessibilityLabel(isSelected ? "\(style.displayName) 선택 해제" : "\(style.displayName) 선택")
    }
}
