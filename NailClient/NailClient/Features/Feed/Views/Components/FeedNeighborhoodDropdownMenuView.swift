//
//  FeedNeighborhoodDropdownMenuView.swift
//  NailClient
//

import SwiftUI

struct FeedNeighborhoodDropdownMenuView: View {
    let entries: [FeedViewModel.QuickNeighborhoodEntry]
    let onSelectEntry: (FeedViewModel.QuickNeighborhoodEntry) -> Void
    let onTapSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries) { entry in
                Button {
                    onSelectEntry(entry)
                } label: {
                    HStack(spacing: 8) {
                        Text(entry.title)
                            .font(.system(size: 17, weight: entry.kind == .current ? .bold : .medium))
                            .foregroundStyle(textColor(for: entry))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if entry.isSelected && entry.kind != .current {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FeedDesignTokens.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .fullRowTapTarget(alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.title)
            }

            Divider()
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 4)

            Button {
                onTapSettings()
            } label: {
                Text("내 동네 설정")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .fullRowTapTarget(alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("내 동네 설정")
        }
        .padding(.vertical, 8)
        .frame(width: 244, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColorTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColorTokens.borderSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private func textColor(for entry: FeedViewModel.QuickNeighborhoodEntry) -> Color {
        switch entry.kind {
        case .current:
            return FeedDesignTokens.primaryText
        case .all:
            return entry.isSelected ? FeedDesignTokens.primaryText : FeedDesignTokens.secondaryText
        case .region:
            return FeedDesignTokens.secondaryText
        }
    }
}
