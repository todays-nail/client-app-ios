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

    private weak var service: (any ShopServicing)?
    private var searchTask: Task<Void, Never>?
    private let debounceDuration: Duration
    private let searchLimit: Int

    init(
        service: (any ShopServicing)? = nil,
        debounceDuration: Duration = .milliseconds(300),
        searchLimit: Int = 20
    ) {
        self.service = service
        self.debounceDuration = debounceDuration
        self.searchLimit = searchLimit
    }

    deinit {
        searchTask?.cancel()
    }

    func bind(service: any ShopServicing) {
        self.service = service
    }

    func retry() {
        let query = normalizedQuery(from: searchText)
        guard !query.isEmpty else {
            state = .idle
            items = []
            return
        }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.runSearch(query: query)
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = normalizedQuery(from: searchText)
        guard !query.isEmpty else {
            items = []
            state = .idle
            return
        }

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: debounceDuration)
            } catch {
                return
            }
            await self?.runSearch(query: query)
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
        } catch is CancellationError {
            return
        } catch {
            guard query == normalizedQuery(from: searchText) else { return }
            items = []
            state = .error("샵 검색에 실패했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private func normalizedQuery(from raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
