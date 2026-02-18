import Foundation

struct FeedReservationOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let unitPrice: Int
    let maxQuantity: Int
    let defaultQuantity: Int
}

extension FeedReservationOption {
    static let defaultTemplates: [FeedReservationOption] = [
        FeedReservationOption(
            id: "cuticle_plus",
            title: "큐티클 케어 업그레이드",
            unitPrice: 5_000,
            maxQuantity: 1,
            defaultQuantity: 0
        ),
        FeedReservationOption(
            id: "premium_topgel",
            title: "프리미엄 탑젤",
            unitPrice: 4_000,
            maxQuantity: 1,
            defaultQuantity: 0
        ),
        FeedReservationOption(
            id: "point_art",
            title: "포인트 아트 추가",
            unitPrice: 12_000,
            maxQuantity: 3,
            defaultQuantity: 0
        ),
        FeedReservationOption(
            id: "parts_addon",
            title: "파츠 추가",
            unitPrice: 8_000,
            maxQuantity: 3,
            defaultQuantity: 0
        ),
        FeedReservationOption(
            id: "soak_off",
            title: "젤 제거",
            unitPrice: 10_000,
            maxQuantity: 1,
            defaultQuantity: 0
        )
    ]

    static var defaultQuantityMap: [String: Int] {
        defaultTemplates.reduce(into: [:]) { partialResult, option in
            partialResult[option.id] = max(0, min(option.defaultQuantity, option.maxQuantity))
        }
    }
}
