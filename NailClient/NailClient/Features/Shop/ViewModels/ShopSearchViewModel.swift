//
//  ShopSearchViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
protocol ShopServicing: AnyObject {
    func searchShops(query: String, limit: Int) async throws -> ShopSearchResponse
    func fetchShopDetail(shopId: UUID) async throws -> ShopDetailResponse
    func fetchShopRecommendations(sido: String?, sigungu: String?, limit: Int) async throws -> ShopRecommendResponse
}

extension AppViewModel: ShopServicing {}

@MainActor
final class ShopSearchViewModel: ObservableObject {
    enum SearchState: Equatable {
        case idle
        case loading
        case results
        case empty
        case error(String)
    }

    @Published var searchText: String = "" {
        didSet {
            scheduleSearch()
        }
    }
    @Published private(set) var state: SearchState = .idle
    @Published private(set) var items: [ShopSummary] = []

    @Published private(set) var currentRegionLabel: String = "위치 확인 중..."
    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var recommendations: [ShopRecommendation] = []
    @Published private(set) var recommendationScope: ShopRecommendationScope = .nationwide
    @Published private(set) var isDiscoverLoading: Bool = false
    @Published private(set) var discoveryErrorMessage: String?

    var isSearchMode: Bool {
        !normalizedQuery(from: searchText).isEmpty
    }

    private weak var service: (any ShopServicing)?
    private let regionProvider: any CurrentRegionProviding
    private let recentSearchStore: any ShopRecentSearchStoring
    private var searchTask: Task<Void, Never>?
    private let debounceDuration: Duration
    private let searchLimit: Int
    private let recommendationLimit: Int
    private var didLoadDiscovery: Bool = false

    init(
        service: (any ShopServicing)? = nil,
        regionProvider: (any CurrentRegionProviding)? = nil,
        recentSearchStore: (any ShopRecentSearchStoring)? = nil,
        debounceDuration: Duration = .milliseconds(300),
        searchLimit: Int = 20,
        recommendationLimit: Int = 3
    ) {
        self.service = service
        self.regionProvider = regionProvider ?? CurrentRegionProvider()
        self.recentSearchStore = recentSearchStore ?? ShopRecentSearchStore()
        self.debounceDuration = debounceDuration
        self.searchLimit = searchLimit
        self.recommendationLimit = recommendationLimit
    }

    deinit {
        searchTask?.cancel()
    }

    func bind(service: any ShopServicing) {
        self.service = service
    }

    func loadDiscoveryIfNeeded() async {
        await loadDiscovery(force: false)
    }

    func refreshDiscovery() async {
        await loadDiscovery(force: true)
    }

    func retry() {
        let query = normalizedQuery(from: searchText)
        guard !query.isEmpty else {
            state = .idle
            items = []
            Task { [weak self] in
                await self?.loadDiscovery(force: true)
            }
            return
        }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.runSearch(query: query)
        }
    }

    func applyRecentSearch(_ query: String) {
        searchText = query
    }

    func removeRecentSearch(_ query: String) {
        recentSearchStore.remove(query: query)
        recentSearches = recentSearchStore.loadRecentSearches()
    }

    func clearRecentSearches() {
        recentSearchStore.clear()
        recentSearches = []
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = normalizedQuery(from: searchText)
        guard !query.isEmpty else {
            items = []
            state = .idle

            Task { [weak self] in
                await self?.loadDiscovery(force: false)
            }
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: self.debounceDuration)
            } catch {
                return
            }
            await self.runSearch(query: query)
        }
    }

    private func runSearch(query: String) async {
        guard !Task.isCancelled else { return }
        guard let service else { return }

        state = .loading

        do {
            let response = try await service.searchShops(query: query, limit: searchLimit)
            guard !Task.isCancelled else { return }
            guard query == normalizedQuery(from: searchText) else { return }

            let mapped = response.items.map { item in
                ShopSummary(
                    id: item.id,
                    name: item.name,
                    address: item.address
                )
            }

            items = mapped
            state = mapped.isEmpty ? .empty : .results

            if !mapped.isEmpty {
                recentSearchStore.save(query: query)
                recentSearches = recentSearchStore.loadRecentSearches()
            }
        } catch is CancellationError {
            return
        } catch {
            guard query == normalizedQuery(from: searchText) else { return }
            items = []
            state = .error("샵 검색에 실패했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private func loadDiscovery(force: Bool) async {
        guard force || !didLoadDiscovery else { return }

        isDiscoverLoading = true
        discoveryErrorMessage = nil
        recentSearches = recentSearchStore.loadRecentSearches()

        let regionResolution = await regionProvider.fetchCurrentRegion()

        var sido: String?
        var sigungu: String?
        switch regionResolution {
        case let .resolved(region):
            currentRegionLabel = region.displayName
            sido = region.sido
            sigungu = region.sigungu
        case .unavailable(.denied), .unavailable(.restricted):
            currentRegionLabel = "위치 권한 필요"
        case .unavailable:
            currentRegionLabel = "위치 확인 실패"
        }

        if let service {
            do {
                let response = try await service.fetchShopRecommendations(
                    sido: sido,
                    sigungu: sigungu,
                    limit: recommendationLimit
                )
                recommendations = response.items.map {
                    ShopRecommendation(
                        id: $0.id,
                        name: $0.name,
                        address: $0.address,
                        likeCount: $0.likeCount
                    )
                }
                recommendationScope = response.scope == "region" ? .region : .nationwide
            } catch {
                recommendations = []
                recommendationScope = .nationwide
                discoveryErrorMessage = "추천 샵을 불러오지 못했어요."
            }
        }

        isDiscoverLoading = false
        didLoadDiscovery = true
    }

    private func normalizedQuery(from raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
