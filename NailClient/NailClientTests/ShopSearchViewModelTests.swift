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
        let viewModel = ShopSearchViewModel(
            service: service,
            debounceDuration: .milliseconds(30)
        )

        viewModel.searchText = "   "
        try? await Task.sleep(for: .milliseconds(80))

        #expect(service.searchQueries.isEmpty)
        #expect(viewModel.state == .idle)
    }

    @Test
    func 입력변경시_이전검색은취소되고_마지막쿼리만호출() async {
        let service = ShopServiceSpy()
        let viewModel = ShopSearchViewModel(
            service: service,
            debounceDuration: .milliseconds(120)
        )

        viewModel.searchText = "g"
        try? await Task.sleep(for: .milliseconds(40))
        viewModel.searchText = "gl"
        try? await Task.sleep(for: .milliseconds(220))

        #expect(service.searchQueries == ["gl"])
    }

    @Test
    func 검색성공시_results상태와매핑결과가설정된다() async {
        let service = ShopServiceSpy()
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
            debounceDuration: .milliseconds(10)
        )

        viewModel.searchText = "glow"
        await waitUntil { viewModel.state == .results }

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.name == "Glow Nail")
    }

    @Test
    func 검색실패시_error상태가된다() async {
        let service = ShopServiceSpy()
        service.searchHandler = { _, _ in
            throw ShopServiceError.forced
        }
        let viewModel = ShopSearchViewModel(
            service: service,
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
    var searchQueries: [String] = []
    var detailQueries: [UUID] = []
    var searchHandler: ((String, Int) async throws -> ShopSearchResponse)?
    var detailHandler: ((UUID) async throws -> ShopDetailResponse)?

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
}

private enum ShopServiceError: Error {
    case forced
}
