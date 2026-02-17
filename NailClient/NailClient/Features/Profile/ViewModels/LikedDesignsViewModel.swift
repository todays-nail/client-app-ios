//
//  LikedDesignsViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
protocol LikedDesignsServicing: AnyObject {
    func fetchLikedFeedList(limit: Int, cursor: String?) async throws -> FeedListResponse
    func setFeedLike(postId: UUID, isLiked: Bool) async throws -> FeedLikeResponse
}

extension AppViewModel: LikedDesignsServicing {}

@MainActor
final class LikedDesignsViewModel: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var likeErrorMessage: String?

    private weak var service: (any LikedDesignsServicing)?
    private var nextCursor: String?
    private var didLoadOnce: Bool = false
    private var inFlightLikeItemIDs: Set<UUID> = []
    private let pageSize: Int

    init(pageSize: Int = 20) {
        self.pageSize = pageSize
    }

    func bind(service: any LikedDesignsServicing) {
        self.service = service
    }

    func loadInitialFeedIfNeeded() async {
        guard !didLoadOnce else { return }
        await loadInitialFeed(force: false)
    }

    func loadInitialFeed(force: Bool = true) async {
        guard let service else { return }
        if isLoading { return }
        if didLoadOnce && !force { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchLikedFeedList(limit: pageSize, cursor: nil)
            items = mapFeedItems(response.items)
            nextCursor = response.nextCursor
            didLoadOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItemID: UUID) async {
        guard !isLoading, !isLoadingMore else { return }
        guard let lastID = items.last?.id, lastID == currentItemID else { return }
        guard let nextCursor, !nextCursor.isEmpty else { return }
        guard let service else { return }

        isLoadingMore = true
        do {
            let response = try await service.fetchLikedFeedList(limit: pageSize, cursor: nextCursor)
            let appended = mapFeedItems(response.items)
            var existing = Set(items.map(\.id))
            for item in appended where !existing.contains(item.id) {
                items.append(item)
                existing.insert(item.id)
            }

            if response.nextCursor == nextCursor {
                self.nextCursor = nil
            } else {
                self.nextCursor = response.nextCursor
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }

    func toggleLike(for itemID: UUID) {
        guard !inFlightLikeItemIDs.contains(itemID) else { return }
        guard let service else { return }
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        guard items[index].isLiked else { return }

        likeErrorMessage = nil
        let removed = items.remove(at: index)
        inFlightLikeItemIDs.insert(itemID)

        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlightLikeItemIDs.remove(itemID) }

            do {
                let response = try await service.setFeedLike(postId: itemID, isLiked: false)
                if response.isLiked {
                    var restored = removed
                    restored.isLiked = true
                    restored.likeCount = max(0, response.likeCount)
                    self.reinsertIfNeeded(restored, preferredIndex: index)
                }
            } catch {
                self.reinsertIfNeeded(removed, preferredIndex: index)
                self.likeErrorMessage = "찜 상태 반영에 실패했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    func applyLikeStateFromDetail(for itemID: UUID, isLiked: Bool, likeCount: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if isLiked == false {
            items.remove(at: index)
            return
        }

        items[index].isLiked = true
        items[index].likeCount = max(0, likeCount)
    }

    private func mapFeedItems(_ responses: [FeedListItemResponse]) -> [FeedItem] {
        responses.map { row in
            FeedItem(
                id: row.id,
                thumbnailURL: URL(string: row.thumbnailURL),
                fallbackAssetName: Self.fallbackAssetName(id: row.id, styleTags: row.styleTags),
                likeCount: row.likeCount,
                shapeCategory: row.shapeCategory,
                isReservable: row.isReservable,
                isLiked: row.isLiked,
                styleTags: row.styleTags,
                createdAt: row.createdAt
            )
        }
    }

    private static func fallbackAssetName(id: UUID, styleTags: [String]) -> String {
        let styleMap: [String: String] = [
            "오피스/미니멀": "office_minimal",
            "청순/내추럴": "natural",
            "러블리/귀여움": "lovely",
            "힙/스트릿": "hip",
            "시크/모던": "chic_modern",
            "키치/유니크": "kitsh_unique",
            "글리터/펄": "glitter_pearl",
            "프렌치": "french",
            "그라데이션/옴브레": "gradient_ombre",
            "웨딩": "wedding",
            "포인트아트": "point-art",
        ]

        for tag in styleTags {
            if let mapped = styleMap[tag] {
                return mapped
            }
        }

        let fallbackPool = FeedMockData.feedItems.map(\.imageName)
        guard !fallbackPool.isEmpty else { return "natural" }

        let seed = id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return fallbackPool[seed % fallbackPool.count]
    }

    private func reinsertIfNeeded(_ item: FeedItem, preferredIndex: Int) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        let targetIndex = min(max(preferredIndex, 0), items.count)
        items.insert(item, at: targetIndex)
    }
}
