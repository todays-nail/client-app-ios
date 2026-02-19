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
                            .appTypography(size: 17, weight: entry.kind == .current ? .bold : .medium)
                            .foregroundStyle(textColor(for: entry))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if entry.isSelected && entry.kind != .current {
                            Image(systemName: "checkmark")
                                .appTypography(size: 13, weight: .semibold)
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
                Text("지역 선택")
                    .appTypography(size: 16, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .fullRowTapTarget(alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("지역 선택")
        }
        .padding(.vertical, 8)
        .frame(width: 244, alignment: .leading)
        .background(
            NeighborhoodDropdownCutoutShape(
                cornerRadius: 18,
                cutoutRadius: 13,
                cutoutInsetTop: 6,
                cutoutInsetRight: 6
            )
            .fill(
                AppColorTokens.cardBackground,
                style: FillStyle(eoFill: true)
            )
        )
        .overlay(
            NeighborhoodDropdownCutoutShape(
                cornerRadius: 18,
                cutoutRadius: 13,
                cutoutInsetTop: 6,
                cutoutInsetRight: 6
            )
            .stroke(AppColorTokens.borderSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private func textColor(for entry: FeedViewModel.QuickNeighborhoodEntry) -> Color {
        switch entry.kind {
        case .current:
            return FeedDesignTokens.primaryText
        case .region:
            return FeedDesignTokens.secondaryText
        }
    }
}

private struct NeighborhoodDropdownCutoutShape: Shape {
    let cornerRadius: CGFloat
    let cutoutRadius: CGFloat
    let cutoutInsetTop: CGFloat
    let cutoutInsetRight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(
            roundedRect: rect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        let cutoutSize = cutoutRadius * 2
        let cutoutRect = CGRect(
            x: rect.maxX - cutoutInsetRight - cutoutSize,
            y: rect.minY + cutoutInsetTop,
            width: cutoutSize,
            height: cutoutSize
        )
        path.addEllipse(in: cutoutRect)
        return path
    }
}
