//
import SwiftUI

struct FeedRegionSelectionView: View {
    let cities: [FeedRegion]
    let districtsByCityID: [UUID: [FeedRegion]]
    let selectedCity: FeedRegion?
    let selectedDistrict: FeedRegion?
    let isLoading: Bool
    let onClose: () -> Void
    let onDone: (FeedRegion?, FeedRegion?) -> Void

    @State private var draftCity: FeedRegion?
    @State private var draftDistrict: FeedRegion?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? 8 : 16)
                        .padding(.bottom, 8)

                    Divider()
                        .padding(.horizontal, 20)

                    allRegionButton
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .background(FeedDesignTokens.screenBackground)

                if isLoading {
                    ProgressView()
                        .tint(FeedDesignTokens.accent)
                        .padding(.top, 40)
                    Spacer()
                } else if cities.isEmpty {
                    VStack {
                        Spacer(minLength: 0)
                        Text("지역 목록이 없어요.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FeedDesignTokens.secondaryText)
                        Text("다시 열어 전체 지역으로 이용할 수 있어요.")
                            .font(.system(size: 13))
                            .foregroundStyle(FeedDesignTokens.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 6)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 12) {
                        regionColumn(
                            title: "시/도",
                            items: cities,
                            selectedID: draftCity?.id,
                            onSelect: { city in
                                draftCity = city
                                if draftDistrict.flatMap({ $0.parentID != city.id }) == true {
                                    draftDistrict = nil
                                }
                            }
                        )

                        regionColumn(
                            title: "구/군",
                            items: selectedDistrictCandidates,
                            selectedID: draftDistrict?.id,
                            onSelect: { district in
                                draftDistrict = district
                                draftCity = city(of: district.parentID)
                            },
                            isSelectable: !selectedDistrictCandidates.isEmpty
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                Spacer()
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    doneButton
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FeedDesignTokens.screenBackground.ignoresSafeArea())
            .ignoresSafeArea()
            .onAppear {
                draftCity = selectedCity
                draftDistrict = selectedDistrict

                if let draftCity, draftCity != city(of: draftDistrict?.parentID) {
                    draftDistrict = nil
                }
            }
        }
    }

    private var selectedDistrictCandidates: [FeedRegion] {
        guard let draftCity else {
            return []
        }
        return districtsByCityID[draftCity.id] ?? []
    }

    private func city(of parentID: UUID?) -> FeedRegion? {
        guard let parentID else { return nil }
        return cities.first { $0.id == parentID }
    }

    private func regionColumn(
        title: String,
        items: [FeedRegion],
        selectedID: UUID?,
        onSelect: @escaping (FeedRegion) -> Void,
        isSelectable: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FeedDesignTokens.secondaryText)
                .padding(.leading, 4)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if !isSelectable {
                        Text("시/도를 먼저 선택해 주세요.")
                            .font(.system(size: 14))
                            .foregroundStyle(FeedDesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }

                    ForEach(items) { item in
                        RegionRowView(
                            name: item.name,
                            isSelected: selectedID == item.id,
                            onTap: { onSelect(item) }
                        )
                    }
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(FeedDesignTokens.chipBorder, lineWidth: 1)
            )
        }
    }

    private var header: some View {
        HStack {
            Button("닫기") {
                onClose()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(FeedDesignTokens.accent)
            .accessibilityLabel("지역 선택 닫기")

            Spacer()

            Text("지역 선택")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FeedDesignTokens.primaryText)

            Spacer()

            Button("완료") {
                onDone(draftCity, draftCity == nil ? nil : draftDistrict)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(draftCity != nil || draftDistrict == nil ? FeedDesignTokens.accent : FeedDesignTokens.secondaryText)
            .accessibilityLabel("지역 선택 완료")
        }
    }

    private var allRegionButton: some View {
        Button(action: {
            draftCity = nil
            draftDistrict = nil
        }) {
            HStack(spacing: 8) {
                Text("전체 지역")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.primaryText)

                Spacer()

                if draftCity == nil && draftDistrict == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FeedDesignTokens.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(FeedDesignTokens.screenBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(FeedDesignTokens.chipBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("전체 지역")
    }

    private var doneButton: some View {
        Button {
            onDone(draftCity, draftCity == nil ? nil : draftDistrict)
        } label: {
            Text("완료")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(FeedDesignTokens.accent)
                .clipShape(Capsule())
        }
        .accessibilityLabel("지역 선택 완료")
    }
}

private struct RegionRowView: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    private var rowBackground: Color {
        isSelected ? FeedDesignTokens.selectedChipBackground : FeedDesignTokens.screenBackground
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FeedDesignTokens.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FeedDesignTokens.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? FeedDesignTokens.accent.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(name), 선택됨" : name)
    }
}
