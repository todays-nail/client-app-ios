//
//  FeedNeighborhoodDropdownMenuView.swift
//  NailClient
//

import SwiftUI

struct FeedNeighborhoodDropdownMenuView: View {
    let currentRegionTitle: String
    let recentRegionTitle: String?
    let onTapCurrentRegion: () -> Void
    let onTapRecentRegion: () -> Void
    let onTapAddRegion: () -> Void
    let onTapSelectRegion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTapCurrentRegion) {
                HStack(spacing: 8) {
                    Text(currentRegionTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FeedDesignTokens.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FeedDesignTokens.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .fullRowTapTarget(alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("현재 선택 지역")

            Divider()
                .padding(.horizontal, 12)

            Button(action: onTapCurrentRegion) {
                Text(currentRegionTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .fullRowTapTarget(alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("현재 지역 \(currentRegionTitle)")

            if let recentRegionTitle, recentRegionTitle != currentRegionTitle {
                Button(action: onTapRecentRegion) {
                    Text(recentRegionTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FeedDesignTokens.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .fullRowTapTarget(alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("최근 선택 지역 \(recentRegionTitle)")
            }

            Divider()
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 4)

            Button(action: onTapAddRegion) {
                Text("+ 지역 추가하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .fullRowTapTarget(alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("지역 추가하기")
            .accessibilityIdentifier("feed.region.add")

            Button(action: onTapSelectRegion) {
                Text("지역 선택하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .fullRowTapTarget(alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("지역 선택하기")
            .accessibilityIdentifier("feed.region.select")
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
