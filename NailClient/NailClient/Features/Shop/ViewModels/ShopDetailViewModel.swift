//
//  ShopDetailViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class ShopDetailViewModel: ObservableObject {
    @Published private(set) var shop: ShopDetail?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    let shopId: UUID

    private weak var service: (any ShopServicing)?
    private var didLoad: Bool = false

    init(shopId: UUID, service: (any ShopServicing)? = nil) {
        self.shopId = shopId
        self.service = service
    }

    func bind(service: any ShopServicing) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        await load(force: false)
    }

    func reload() async {
        await load(force: true)
    }

    private func load(force: Bool) async {
        guard let service else { return }
        if isLoading { return }
        if didLoad && !force { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchShopDetail(shopId: shopId)
            shop = ShopDetail(
                id: response.shop.id,
                name: response.shop.name,
                address: response.shop.address,
                addressDetail: response.shop.addressDetail,
                phone: response.shop.phone,
                status: response.shop.status,
                intro: response.shop.intro,
                openTime: response.shop.openTime,
                closeTime: response.shop.closeTime,
                closedWeekdays: response.shop.closedWeekdays ?? []
            )
            didLoad = true
        } catch {
            errorMessage = "샵 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        }

        isLoading = false
    }
}
