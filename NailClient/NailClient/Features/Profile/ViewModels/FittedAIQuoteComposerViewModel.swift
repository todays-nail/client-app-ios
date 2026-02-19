//
//  FittedAIQuoteComposerViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class FittedAIQuoteComposerViewModel: ObservableObject {
    enum TargetMode: String, CaseIterable, Identifiable {
        case regionAll
        case selectedShops

        var id: String { rawValue }

        var title: String {
            switch self {
            case .regionAll:
                return "지역 전체"
            case .selectedShops:
                return "샵 직접 선택"
            }
        }

        var description: String {
            switch self {
            case .regionAll:
                return "선택한 지역(하위 포함)의 샵 전체로 견적 요청을 보냅니다."
            case .selectedShops:
                return "검색으로 선택한 샵에만 견적 요청을 보냅니다."
            }
        }

        var apiValue: QuoteTargetMode {
            switch self {
            case .regionAll:
                return .regionAll
            case .selectedShops:
                return .selectedShops
            }
        }
    }

    @Published var targetMode: TargetMode = .regionAll
    @Published var selectedRegionID: UUID?
    @Published private(set) var selectedRegionLabel: String?
    @Published private(set) var selectedServiceScopeID: UUID?
    @Published var selectedShopIDs: Set<UUID> = []
    @Published var shopQuery: String = ""
    @Published var preferredDate: Date = Date()
    @Published var requestNote: String = ""

    @Published private(set) var shopOptions: [ShopSummary] = []
    @Published private(set) var isSearchingShops: Bool = false
    @Published private(set) var isSubmitting: Bool = false
    @Published var isRegionPickerPresented: Bool = false
    @Published var errorMessage: String?

    let regionPickerViewModel: RegionPickerViewModel

    private weak var service: (any FittedAIImagesServicing)?
    private let jobID: UUID
    private let searchLimit: Int

    init(
        jobID: UUID,
        service: any FittedAIImagesServicing,
        searchLimit: Int = 20,
        regionPickerViewModel: RegionPickerViewModel? = nil
    ) {
        self.jobID = jobID
        self.service = service
        self.searchLimit = max(1, min(searchLimit, 50))
        self.regionPickerViewModel = regionPickerViewModel ?? RegionPickerViewModel()
    }

    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard selectedRegionID != nil else { return false }
        guard !trimmedRequestNote.isEmpty else { return false }

        switch targetMode {
        case .regionAll:
            return true
        case .selectedShops:
            return !selectedShopIDs.isEmpty
        }
    }

    var preferredDateText: String {
        Self.dateFormatter.string(from: preferredDate)
    }

    var selectedRegionDisplayText: String {
        selectedRegionLabel ?? "지역을 선택해 주세요"
    }

    func isShopSelected(_ shopID: UUID) -> Bool {
        selectedShopIDs.contains(shopID)
    }

    func selectedShopCountText() -> String {
        "선택된 샵 \(selectedShopIDs.count)개"
    }

    func loadIfNeeded() async {
        guard let service else { return }
        await regionPickerViewModel.loadIfNeeded(service: service)

        if selectedRegionID == nil,
           let currentRegionID = regionPickerViewModel.currentRegionID,
           let path = regionPickerViewModel.pathToRegion(currentRegionID),
           let leaf = path.last {
            selectedRegionID = leaf.id
            selectedServiceScopeID = leaf.serviceScopeID
            selectedRegionLabel = path.map(\.name).joined(separator: " ")
        }
    }

    func targetModeDidChange() {
        errorMessage = nil
        if targetMode == .regionAll {
            selectedShopIDs = []
            shopOptions = []
        }
    }

    func handleRegionSelection(_ result: RegionPickerViewModel.SelectionResult) {
        if selectedRegionID != result.selectedRegionID {
            selectedShopIDs = []
            shopOptions = []
        }

        selectedRegionID = result.selectedRegionID
        selectedServiceScopeID = result.selectedServiceScopeID
        selectedRegionLabel = result.selectedLabel
        errorMessage = nil
    }

    func searchShops() async {
        guard let service else { return }
        if isSearchingShops { return }

        guard let scopeRegionID = selectedServiceScopeID ?? selectedRegionID else {
            errorMessage = "먼저 지역을 선택해 주세요."
            return
        }

        let query = shopQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            shopOptions = []
            return
        }

        isSearchingShops = true
        defer { isSearchingShops = false }

        do {
            let response = try await service.searchShops(
                query: query,
                limit: searchLimit,
                regionId: scopeRegionID
            )
            shopOptions = response.items.map {
                ShopSummary(
                    id: $0.id,
                    name: $0.name,
                    address: $0.address
                )
            }
            let validIDs = Set(shopOptions.map(\.id))
            selectedShopIDs = selectedShopIDs.filter { validIDs.contains($0) }
            errorMessage = nil
        } catch {
            errorMessage = "샵 검색에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func toggleShopSelection(_ shopID: UUID) {
        if selectedShopIDs.contains(shopID) {
            selectedShopIDs.remove(shopID)
        } else {
            selectedShopIDs.insert(shopID)
        }
    }

    func submit() async -> Bool {
        guard let service else { return false }
        guard !isSubmitting else { return false }

        guard let selectedRegionID else {
            errorMessage = "지역을 선택해 주세요."
            return false
        }

        if trimmedRequestNote.isEmpty {
            errorMessage = "요청 메모를 입력해 주세요."
            return false
        }

        let selectedShopIDs = Array(selectedShopIDs)
        if targetMode == .selectedShops && selectedShopIDs.isEmpty {
            errorMessage = "요청할 샵을 1개 이상 선택해 주세요."
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await service.createQuoteRequest(
                jobId: jobID,
                targetMode: targetMode.apiValue,
                regionId: selectedServiceScopeID ?? selectedRegionID,
                selectedShopIDs: selectedShopIDs,
                preferredDate: Self.apiDateFormatter.string(from: preferredDate),
                requestNote: trimmedRequestNote
            )
            errorMessage = nil
            return true
        } catch {
            errorMessage = "견적 요청 생성에 실패했어요. 잠시 후 다시 시도해 주세요."
            return false
        }
    }

    private var trimmedRequestNote: String {
        requestNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateStyle = .medium
        return formatter
    }()
}
