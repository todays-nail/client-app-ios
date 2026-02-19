#if false
//
//  ShopSearchViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct ShopSearchViewModelTests {
    @Test
    func 빈쿼리면_검색호출하지않고_idle상태() async {
        let service = ShopServiceSpy()
        service.recommendHandler = { _, _, _ in
            ShopRecommendResponse(scope: "nationwide", regionLabel: nil, items: [])
        }

        let viewModel = ShopSearchViewModel(
            service: service,
            regionProvider: RegionProviderStub(result: .resolved(ShopRegion(sido: "서울", sigungu: "강남구"))),
            recentSearchStore: RecentSearchStoreSpy(),
            debounceDuration: .milliseconds(30)
        )

        viewModel.searchText = "   "
        try? await Task.sleep(for: .milliseconds(100))

        #expect(service.searchQueries.isEmpty)
        #expect(viewModel.state == .idle)
    }

    @Test
    func 입력변경시_이전검색은취소되고_마지막쿼리만호출() async {
        let service = ShopServiceSpy()
        service.searchHandler = { _, _ in
            try? await Task.sleep(for: .milliseconds(30))
            return ShopSearchResponse(items: [])
        }

        let viewModel = ShopSearchViewModel(
            service: service,
            regionProvider: RegionProviderStub(result: .resolved(ShopRegion(sido: "서울", sigungu: "강남구"))),
            recentSearchStore: RecentSearchStoreSpy(),
            debounceDuration: .milliseconds(120)
        )

        viewModel.searchText = "g"
        try? await Task.sleep(for: .milliseconds(40))
        viewModel.searchText = "gl"
        try? await Task.sleep(for: .milliseconds(260))

        #expect(service.searchQueries == ["gl"])
    }

    @Test
    func 검색성공시_results상태와매핑결과가설정되고_최근검색이저장된다() async {
        let service = ShopServiceSpy()
        let recentStore = RecentSearchStoreSpy()
        service.searchHandler = { _, _ in
            ShopSearchResponse(
                items: [
                    ShopSearchItemResponse(
                        id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                        name: "Glow Nail",
                        address: "강남구 신사동"
                    )
                ]
            )
        }

        let viewModel = ShopSearchViewModel(
            service: service,
            regionProvider: RegionProviderStub(result: .resolved(ShopRegion(sido: "서울", sigungu: "강남구"))),
            recentSearchStore: recentStore,
            debounceDuration: .milliseconds(10)
        )

        viewModel.searchText = "glow"
        await waitUntil { viewModel.state == .results }

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.name == "Glow Nail")
        #expect(recentStore.savedQueries.last == "glow")
        #expect(viewModel.recentSearches.first == "glow")
    }

    @Test
    func 검색실패시_error상태가된다() async {
        let service = ShopServiceSpy()
        service.searchHandler = { _, _ in
            throw ShopServiceError.forced
        }

        let viewModel = ShopSearchViewModel(
            service: service,
            regionProvider: RegionProviderStub(result: .resolved(ShopRegion(sido: "서울", sigungu: "강남구"))),
            recentSearchStore: RecentSearchStoreSpy(),
            debounceDuration: .milliseconds(10)
        )

        viewModel.searchText = "glow"
        await waitUntil {
            if case .error = viewModel.state { return true }
            return false
        }

        if case let .error(message) = viewModel.state {
            #expect(message.isEmpty == false)
        } else {
            Issue.record("error 상태가 아닙니다.")
        }
    }

    @Test
    func 위치권한거부시_전국추천으로_fallback된다() async {
        let service = ShopServiceSpy()
        service.recommendHandler = { sido, sigungu, _ in
            #expect(sido == nil)
            #expect(sigungu == nil)
            return ShopRecommendResponse(
                scope: "nationwide",
                regionLabel: nil,
                items: [
                    ShopRecommendItemResponse(
                        id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                        name: "Dear Nail",
                        address: "서울시 송파구",
                        likeCount: 21
                    )
                ]
            )
        }

        let viewModel = ShopSearchViewModel(
            service: service,
            regionProvider: RegionProviderStub(result: .unavailable(.denied)),
            recentSearchStore: RecentSearchStoreSpy(),
            debounceDuration: .milliseconds(10)
        )

        await viewModel.loadDiscoveryIfNeeded()

        #expect(viewModel.currentRegionLabel == "위치 권한 필요")
        #expect(viewModel.recommendationScope == .nationwide)
        #expect(viewModel.recommendations.count == 1)
        #expect(service.recommendQueries.count == 1)
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let started = clock.now

        while !condition() {
            if started.duration(to: clock.now) > timeout {
                break
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class ShopServiceSpy: ShopServicing {
    struct RecommendQuery: Equatable {
        let sido: String?
        let sigungu: String?
        let limit: Int
    }

    var searchQueries: [String] = []
    var detailQueries: [UUID] = []
    var recommendQueries: [RecommendQuery] = []

    var searchHandler: ((String, Int) async throws -> ShopSearchResponse)?
    var detailHandler: ((UUID) async throws -> ShopDetailResponse)?
    var recommendHandler: ((String?, String?, Int) async throws -> ShopRecommendResponse)?

    func searchShops(query: String, limit: Int) async throws -> ShopSearchResponse {
        searchQueries.append(query)
        if let searchHandler {
            return try await searchHandler(query, limit)
        }
        return ShopSearchResponse(items: [])
    }

    func fetchShopDetail(shopId: UUID) async throws -> ShopDetailResponse {
        detailQueries.append(shopId)
        if let detailHandler {
            return try await detailHandler(shopId)
        }
        throw ShopServiceError.forced
    }

    func fetchShopRecommendations(sido: String?, sigungu: String?, limit: Int) async throws -> ShopRecommendResponse {
        recommendQueries.append(RecommendQuery(sido: sido, sigungu: sigungu, limit: limit))
        if let recommendHandler {
            return try await recommendHandler(sido, sigungu, limit)
        }
        return ShopRecommendResponse(scope: "nationwide", regionLabel: nil, items: [])
    }
}

@MainActor
private final class RegionProviderStub: CurrentRegionProviding {
    let result: ShopRegionResolution

    init(result: ShopRegionResolution) {
        self.result = result
    }

    func fetchCurrentRegion() async -> ShopRegionResolution {
        result
    }
}

private final class RecentSearchStoreSpy: ShopRecentSearchStoring {
    private(set) var values: [String] = []
    private(set) var savedQueries: [String] = []

    func loadRecentSearches() -> [String] {
        values
    }

    func save(query: String) {
        savedQueries.append(query)
        values.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        values.insert(query, at: 0)
        if values.count > 10 {
            values = Array(values.prefix(10))
        }
    }

    func remove(query: String) {
        values.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
    }

    func clear() {
        values = []
    }
}

private enum ShopServiceError: Error {
    case forced
}

#endif
