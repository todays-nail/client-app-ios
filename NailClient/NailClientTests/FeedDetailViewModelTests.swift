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

    private func makeItem() -> FeedItem {
        FeedItem(
            id: UUID(),
            imageName: "natural",
            likeCount: 8,
            shapeCategory: "아몬드",
            isReservable: true
        )
    }

    private func makeResponse(postId: UUID, title: String) -> FeedDetailResponse {
        FeedDetailResponse(
            post: FeedDetailPostResponse(
                id: postId,
                title: title,
                thumbnailURL: "https://example.com/thumb.jpg",
                likeCount: 22,
                shapeCategory: "아몬드",
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

    func waitUntilSuspended() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func complete(with response: FeedDetailResponse) {
        continuation?.resume(returning: response)
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
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
}
