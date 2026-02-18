//
//  FittedAIQuoteComposerViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class FittedAIQuoteComposerViewModel: ObservableObject {
    enum TargetType: String, CaseIterable, Identifiable {
        case region
        case shop

        var id: String { rawValue }

        var title: String {
            switch self {
            case .region:
                return "지역"
            case .shop:
                return "샵"
            }
        }
    }

    struct RegionOption: Identifiable, Equatable {
        let id: UUID
        let displayName: String
        let isDistrict: Bool
    }

    @Published var targetType: TargetType = .region
    @Published var selectedRegionID: UUID?
    @Published var selectedShopID: UUID?
    @Published var shopQuery: String = ""

    @Published private(set) var regionOptions: [RegionOption] = []
    @Published private(set) var shopOptions: [ShopSummary] = []
    @Published private(set) var isLoadingRegions: Bool = false
    @Published private(set) var isSearchingShops: Bool = false
    @Published private(set) var isSubmitting: Bool = false
    @Published var errorMessage: String?

    private weak var service: (any FittedAIImagesServicing)?
    private let jobID: UUID
    private var didLoadRegions: Bool = false
    private let searchLimit: Int

    init(
        jobID: UUID,
        service: any FittedAIImagesServicing,
        searchLimit: Int = 20
    ) {
        self.jobID = jobID
        self.service = service
        self.searchLimit = max(1, min(searchLimit, 50))
    }

    var canSubmit: Bool {
        if isSubmitting { return false }
        switch targetType {
        case .region:
            return selectedRegionID != nil
        case .shop:
            return selectedShopID != nil
        }
    }

    func loadIfNeeded() async {
        guard targetType == .region else { return }
        await loadRegionsIfNeeded(force: false)
    }

    func targetTypeDidChange() async {
        errorMessage = nil
        if targetType == .region {
            await loadRegionsIfNeeded(force: false)
            selectedShopID = nil
        } else {
            selectedRegionID = nil
        }
    }

    func loadRegionsIfNeeded(force: Bool) async {
        guard force || !didLoadRegions else { return }
        guard let service else { return }
        if isLoadingRegions { return }

        isLoadingRegions = true
        defer { isLoadingRegions = false }

        do {
            let response = try await service.fetchRegions()
            var options: [RegionOption] = []
            for city in response.cities {
                options.append(
                    RegionOption(
                        id: city.id,
                        displayName: city.name,
                        isDistrict: false
                    )
                )
                for district in city.districts {
                    options.append(
                        RegionOption(
                            id: district.id,
                            displayName: "\(city.name) \(district.name)",
                            isDistrict: true
                        )
                    )
                }
            }
            regionOptions = options
            if let selectedRegionID, regionOptions.contains(where: { $0.id == selectedRegionID }) == false {
                self.selectedRegionID = nil
            }
            didLoadRegions = true
            errorMessage = nil
        } catch {
            errorMessage = "지역 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func searchShops() async {
        guard let service else { return }
        if isSearchingShops { return }

        let query = shopQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            shopOptions = []
            selectedShopID = nil
            return
        }

        isSearchingShops = true
        defer { isSearchingShops = false }

        do {
            let response = try await service.searchShops(query: query, limit: searchLimit)
            shopOptions = response.items.map {
                ShopSummary(
                    id: $0.id,
                    name: $0.name,
                    address: $0.address
                )
            }
            if let selectedShopID, shopOptions.contains(where: { $0.id == selectedShopID }) == false {
                self.selectedShopID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = "샵 검색에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func submit() async -> Bool {
        guard let service else { return false }
        guard !isSubmitting else { return false }

        switch targetType {
        case .region:
            guard let selectedRegionID else {
                errorMessage = "지역을 선택해 주세요."
                return false
            }
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                _ = try await service.createQuoteRequest(
                    jobId: jobID,
                    targetType: .region,
                    regionId: selectedRegionID,
                    shopId: nil
                )
                errorMessage = nil
                return true
            } catch {
                errorMessage = "견적 생성에 실패했어요. 잠시 후 다시 시도해 주세요."
                return false
            }
        case .shop:
            guard let selectedShopID else {
                errorMessage = "샵을 선택해 주세요."
                return false
            }
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                _ = try await service.createQuoteRequest(
                    jobId: jobID,
                    targetType: .shop,
                    regionId: nil,
                    shopId: selectedShopID
                )
                errorMessage = nil
                return true
            } catch {
                errorMessage = "견적 생성에 실패했어요. 잠시 후 다시 시도해 주세요."
                return false
            }
        }
    }
}
