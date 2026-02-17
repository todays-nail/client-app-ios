//
//  ShopDetailViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct ShopDetailViewModelTests {
    @Test
    func loadIfNeeded_성공시_샵상세를설정한다() async {
        let shopId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let service = ShopDetailServiceSpy(
            detailResults: [.success(makeDetailResponse(shopId: shopId, name: "Glow Nail"))]
        )
        let viewModel = ShopDetailViewModel(shopId: shopId, service: service)

        await viewModel.loadIfNeeded()

        #expect(viewModel.shop?.id == shopId)
        #expect(viewModel.shop?.name == "Glow Nail")
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadIfNeeded_실패시_에러메시지를설정한다() async {
        let shopId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let service = ShopDetailServiceSpy(
            detailResults: [.failure(ShopDetailServiceError.forced)]
        )
        let viewModel = ShopDetailViewModel(shopId: shopId, service: service)

        await viewModel.loadIfNeeded()

        #expect(viewModel.shop == nil)
        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    @Test
    func reload_재시도하면_성공응답으로회복된다() async {
        let shopId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let service = ShopDetailServiceSpy(
            detailResults: [
                .failure(ShopDetailServiceError.forced),
                .success(makeDetailResponse(shopId: shopId, name: "Dear Nail")),
            ]
        )
        let viewModel = ShopDetailViewModel(shopId: shopId, service: service)

        await viewModel.loadIfNeeded()
        #expect(viewModel.shop == nil)

        await viewModel.reload()

        #expect(viewModel.shop?.name == "Dear Nail")
        #expect(viewModel.errorMessage == nil)
    }

    private func makeDetailResponse(shopId: UUID, name: String) -> ShopDetailResponse {
        ShopDetailResponse(
            shop: ShopDetailItemResponse(
                id: shopId,
                name: name,
                address: "강남구 신사동",
                addressDetail: "101호",
                phone: "010-1234-5678",
                status: "VERIFIED",
                intro: "반갑습니다.",
                openTime: "10:00:00",
                closeTime: "20:00:00",
                closedWeekdays: ["SUN"]
            )
        )
    }
}

@MainActor
private final class ShopDetailServiceSpy: ShopServicing {
    private var detailResults: [Result<ShopDetailResponse, Error>]

    init(detailResults: [Result<ShopDetailResponse, Error>]) {
        self.detailResults = detailResults
    }

    func searchShops(query: String, limit: Int) async throws -> ShopSearchResponse {
        ShopSearchResponse(items: [])
    }

    func fetchShopDetail(shopId: UUID) async throws -> ShopDetailResponse {
        if detailResults.isEmpty {
            throw ShopDetailServiceError.forced
        }
        return try detailResults.removeFirst().get()
    }
}

private enum ShopDetailServiceError: Error {
    case forced
}
