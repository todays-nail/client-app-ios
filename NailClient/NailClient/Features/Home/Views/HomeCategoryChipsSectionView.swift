//
//  HomeCategoryChipsSectionView.swift
//  NailClient
//

import SwiftUI

struct HomeCategoryChipsSectionView: View {
    let categories: [String]
    let selectedCategory: String
    let onSelectCategory: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        onSelectCategory(category)
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
            }
            .padding(.horizontal, 2)
        }
    }
}
