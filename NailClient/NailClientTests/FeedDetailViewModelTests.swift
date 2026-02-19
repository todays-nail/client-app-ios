#if false
//
//  FeedDetailViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct FeedDetailViewModelTests {
    @Test
    func 초기로드_시작중에는_isInitialLoading_true() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let loadTask = Task {
            await viewModel.loadIfNeeded()
        }

        await service.waitUntilSuspended()

        #expect(viewModel.isLoading == true)
        #expect(viewModel.isInitialLoading == true)

        service.complete(with: makeResponse(postId: item.id, title: "첫 로드"))
        await loadTask.value
    }

    @Test
    func 초기로드_성공후_isInitialLoading_false_and_detail존재() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let loadTask = Task {
            await viewModel.loadIfNeeded()
        }

        await service.waitUntilSuspended()
        service.complete(with: makeResponse(postId: item.id, title: "완료"))
        await loadTask.value

        #expect(viewModel.isInitialLoading == false)
        #expect(viewModel.detail?.id == item.id)
    }

    @Test
    func detail존재상태에서_reload중_isInitialLoading_false유지() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let firstLoadTask = Task {
            await viewModel.loadIfNeeded()
        }
        await service.waitUntilSuspended()
        service.complete(with: makeResponse(postId: item.id, title: "초기"))
        await firstLoadTask.value

        let reloadTask = Task {
            await viewModel.reload()
        }
        await service.waitUntilSuspended()

        #expect(viewModel.detail != nil)
        #expect(viewModel.isLoading == true)
        #expect(viewModel.isInitialLoading == false)

        service.complete(with: makeResponse(postId: item.id, title: "재로드"))
        await reloadTask.value
    }

    @Test
    func toggleLike_성공하면서버응답으로동기화() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        service.likeResult = .success(
            FeedLikeResponse(ok: true, postId: item.id, isLiked: true, likeCount: 77)
        )
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let response = await viewModel.toggleLike()

        #expect(response?.isLiked == true)
        #expect(viewModel.isLiked == true)
        #expect(viewModel.likeCount == 77)
        #expect(viewModel.likeErrorMessage == nil)
    }

    @Test
    func toggleLike_실패하면롤백하고에러노출() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        service.likeResult = .failure(FeedDetailServiceError.forcedFailure)
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let response = await viewModel.toggleLike()

        #expect(response == nil)
        #expect(viewModel.isLiked == false)
        #expect(viewModel.likeCount == 8)
        #expect(viewModel.likeErrorMessage?.isEmpty == false)
    }

    @Test
    func shopId_이미있으면_재조회없이반환() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        let shopId = UUID()
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let loadTask = Task {
            await viewModel.loadIfNeeded()
        }
        await service.waitUntilSuspended()
        service.complete(with: makeResponse(postId: item.id, title: "초기", shopId: shopId))
        await loadTask.value

        let resolvedShopId = await viewModel.resolveShopIdForNavigation()

        #expect(resolvedShopId == shopId)
        #expect(service.fetchFeedDetailCallCount == 1)
    }

    @Test
    func shopId_없으면_reload후_반환() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        let shopId = UUID()
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let loadTask = Task {
            await viewModel.loadIfNeeded()
        }
        await service.waitUntilSuspended()
        service.complete(with: makeResponse(postId: item.id, title: "초기", shopId: nil))
        await loadTask.value

        let resolveTask = Task {
            await viewModel.resolveShopIdForNavigation()
        }
        await service.waitUntilSuspended()
        service.complete(with: makeResponse(postId: item.id, title: "재조회", shopId: shopId))
        let resolvedShopId = await resolveTask.value

        #expect(resolvedShopId == shopId)
        #expect(service.fetchFeedDetailCallCount == 2)
    }

    @Test
    func shopId_재조회후에도없거나실패하면_nil반환() async {
        let item = makeItem()
        let service = ControlledFeedDetailService()
        let viewModel = FeedDetailViewModel(item: item, service: service)

        let loadTask = Task {
            await viewModel.loadIfNeeded()
        }
        await service.waitUntilSuspended()
        service.complete(with: makeResponse(postId: item.id, title: "초기", shopId: nil))
        await loadTask.value

        let resolveTask = Task {
            await viewModel.resolveShopIdForNavigation()
        }
        await service.waitUntilSuspended()
        service.failFetch(with: FeedDetailServiceError.forcedFailure)
        let resolvedShopId = await resolveTask.value

        #expect(resolvedShopId == nil)
        #expect(service.fetchFeedDetailCallCount == 2)
    }

    private func makeItem() -> FeedItem {
        FeedItem(
            id: UUID(),
            imageName: "natural",
            likeCount: 8,
            isReservable: true
        )
    }

    private func makeResponse(postId: UUID, title: String, shopId: UUID? = nil) -> FeedDetailResponse {
        FeedDetailResponse(
            post: FeedDetailPostResponse(
                id: postId,
                title: title,
                thumbnailURL: "https://example.com/thumb.jpg",
                shopId: shopId,
                likeCount: 22,
                isReservable: true,
                isLiked: false,
                styleTags: ["프렌치"],
                studioName: "Glow",
                locationText: "강남구",
                distanceKM: 1.3,
                originalPrice: 60000,
                discountedPrice: 50000,
                durationMin: 60,
                description: "테스트 설명",
                reviewCount: 3,
                ratingAvg: 4.8,
                createdAt: Date()
            ),
            galleryImageURLs: ["https://example.com/a.jpg"],
            recentReviews: []
        )
    }
}

@MainActor
private final class ControlledFeedDetailService: FeedServicing {
    private var continuation: CheckedContinuation<FeedDetailResponse, Error>?
    private(set) var fetchFeedDetailCallCount: Int = 0
    var likeResult: Result<FeedLikeResponse, Error> = .success(
        FeedLikeResponse(
            ok: true,
            postId: UUID(),
            isLiked: true,
            likeCount: 1
        )
    )

    func waitUntilSuspended() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func complete(with response: FeedDetailResponse) {
        continuation?.resume(returning: response)
        continuation = nil
    }

    func failFetch(with error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func fetchFeedList(
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> FeedListResponse {
        FeedListResponse(items: [], nextCursor: nil)
    }

    func fetchFeedDetail(postId: UUID) async throws -> FeedDetailResponse {
        fetchFeedDetailCallCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func setFeedLike(postId: UUID, isLiked: Bool) async throws -> FeedLikeResponse {
        try likeResult.get()
    }
}

private enum FeedDetailServiceError: Error {
    case forcedFailure
}

#endif
