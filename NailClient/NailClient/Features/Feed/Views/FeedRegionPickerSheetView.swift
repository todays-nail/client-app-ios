//
//  FeedRegionPickerSheetView.swift
//  NailClient
//

import SwiftUI

struct FeedRegionSelectionView: View {
    let cities: [FeedRegion]
    let selectedCity: FeedRegion?
    let state: FeedViewModel.RegionPickerState
    let isMandatory: Bool
    let onClose: () -> Void
    let onRetry: () -> Void
    let onDone: (FeedRegion) -> Void

    @State private var draftCity: FeedRegion?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, geometry.safeAreaInsets.top > 0 ? 10 : 16)
                    .padding(.bottom, 10)

                Divider()
                    .padding(.bottom, 8)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    doneButton
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                }
                .background(FeedDesignTokens.screenBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FeedDesignTokens.screenBackground)
            .onAppear {
                draftCity = selectedCity
            }
            .onChange(of: selectedCity?.id) { _, _ in
                draftCity = selectedCity
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            VStack(spacing: 12) {
                Spacer(minLength: 20)
                ProgressView()
                    .tint(FeedDesignTokens.accent)
                Text("지역 목록을 불러오는 중이에요.")
                    .appTypography(size: 14, weight: .medium)
                    .foregroundStyle(FeedDesignTokens.secondaryText)
                Spacer(minLength: 0)
            }
        case .failed:
            RegionPickerStateMessageView(
                title: "지역 정보를 불러오지 못했어요.",
                subtitle: "네트워크 상태를 확인한 뒤 다시 시도해 주세요.",
                buttonTitle: "다시 시도",
                onTapButton: onRetry
            )
        case .empty:
            RegionPickerStateMessageView(
                title: "선택할 수 있는 지역이 없어요.",
                subtitle: "잠시 후 다시 시도해 주세요.",
                buttonTitle: "다시 시도",
                onTapButton: onRetry
            )
        case .loaded:
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(cities) { city in
                        RegionRowView(
                            name: city.name,
                            isSelected: draftCity?.id == city.id,
                            accessibilityIdentifier: "feed.region.city.\(city.id.uuidString.lowercased())",
                            onTap: { draftCity = city }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack {
            if isMandatory {
                Text("닫기")
                    .appTypography(size: 16, weight: .semibold)
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
            } else {
                Button("닫기") {
                    onClose()
                }
                .appTypography(size: 16, weight: .semibold)
                .foregroundStyle(FeedDesignTokens.accent)
                .accessibilityLabel("지역 선택 닫기")
            }

            Spacer()

            Text("지역 선택")
                .appTypography(size: 18, weight: .bold)
                .foregroundStyle(FeedDesignTokens.primaryText)

            Spacer()

            Button("완료") {
                guard let draftCity else { return }
                onDone(draftCity)
            }
            .appTypography(size: 16, weight: .semibold)
            .foregroundStyle(draftCity == nil ? FeedDesignTokens.secondaryText : FeedDesignTokens.accent)
            .disabled(draftCity == nil)
            .accessibilityLabel("지역 선택 완료")
        }
    }

    private var doneButton: some View {
        Button {
            guard let draftCity else { return }
            onDone(draftCity)
        } label: {
            Text("완료")
                .appTypography(size: 16, weight: .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(draftCity == nil ? FeedDesignTokens.secondaryText.opacity(0.5) : FeedDesignTokens.accent)
                .clipShape(Capsule())
        }
        .disabled(draftCity == nil)
        .accessibilityLabel("지역 선택 완료")
    }
}

private struct RegionPickerStateMessageView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let onTapButton: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 30)
            Text(title)
                .appTypography(size: 16, weight: .semibold)
                .foregroundStyle(FeedDesignTokens.primaryText)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .appTypography(size: 14)
                .foregroundStyle(FeedDesignTokens.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: onTapButton) {
                Text(buttonTitle)
                    .appTypography(size: 15, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(FeedDesignTokens.accent)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RegionRowView: View {
    let name: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let onTap: () -> Void

    private var rowBackground: Color {
        isSelected ? FeedDesignTokens.selectedChipBackground : FeedDesignTokens.screenBackground
    }

    private var rowTextColor: Color {
        isSelected ? .white : FeedDesignTokens.primaryText
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(name)
                    .appTypography(size: 15, weight: .semibold)
                    .foregroundStyle(rowTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .appTypography(size: 15, weight: .semibold)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? FeedDesignTokens.selectedChipBackground : FeedDesignTokens.chipBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(isSelected ? "\(name), 선택됨" : name)
    }
}
