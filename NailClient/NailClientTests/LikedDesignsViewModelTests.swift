//
//  LikedDesignsViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct LikedDesignsViewModelTests {
    @Test
    func 초기로드_성공시_아이템을반환한다() async {
        let item = makeFeedListItem(id: UUID(), likeCount: 33)
        let service = MockLikedDesignsService(
            listResults: [
                .success(FeedListResponse(items: [item], nextCursor: nil))
            ]
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].likeCount == 33)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func 초기로드_응답에_unliked가섞여도_찜항목만반영한다() async {
        let liked = makeFeedListItem(id: UUID(), likeCount: 33, isLiked: true)
        let unliked = makeFeedListItem(id: UUID(), likeCount: 99, isLiked: false)
        let service = MockLikedDesignsService(
            listResults: [
                .success(FeedListResponse(items: [liked, unliked], nextCursor: nil))
            ]
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].id == liked.id)
        #expect(viewModel.items[0].isLiked == true)
    }

    @Test
    func 초기로드_실패시_에러를노출한다() async {
        let service = MockLikedDesignsService(
            listResults: [
                .failure(LikedDesignsMockError.forcedFailure)
            ]
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    @Test
    func 페이지네이션_커서가있으면_다음목록을추가한다() async {
        let first = makeFeedListItem(id: UUID(), likeCount: 10)
        let second = makeFeedListItem(id: UUID(), likeCount: 20)
        let service = MockLikedDesignsService(
            listResults: [
                .success(FeedListResponse(items: [first], nextCursor: "cursor-1")),
                .success(FeedListResponse(items: [second], nextCursor: nil))
            ]
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)
        await viewModel.loadInitialFeed(force: true)

        guard let targetID = viewModel.items.last?.id else {
            Issue.record("초기 로드 아이템이 없습니다.")
            return
        }

        await viewModel.loadMoreIfNeeded(currentItemID: targetID)

        #expect(viewModel.items.count == 2)
        #expect(viewModel.items[1].likeCount == 20)
    }

    @Test
    func 페이지네이션_응답에_unliked가있으면_추가하지않는다() async {
        let first = makeFeedListItem(id: UUID(), likeCount: 10, isLiked: true)
        let likedSecond = makeFeedListItem(id: UUID(), likeCount: 20, isLiked: true)
        let unlikedSecond = makeFeedListItem(id: UUID(), likeCount: 30, isLiked: false)
        let service = MockLikedDesignsService(
            listResults: [
                .success(FeedListResponse(items: [first], nextCursor: "cursor-1")),
                .success(FeedListResponse(items: [likedSecond, unlikedSecond], nextCursor: nil))
            ]
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)
        await viewModel.loadInitialFeed(force: true)

        guard let targetID = viewModel.items.last?.id else {
            Issue.record("초기 로드 아이템이 없습니다.")
            return
        }

        await viewModel.loadMoreIfNeeded(currentItemID: targetID)

        #expect(viewModel.items.count == 2)
        #expect(viewModel.items.contains(where: { $0.id == likedSecond.id }))
        #expect(viewModel.items.contains(where: { $0.id == unlikedSecond.id }) == false)
    }

    @Test
    func unlike_요청시_목록에서즉시제거되고_성공시유지된다() async {
        let targetID = UUID()
        let service = MockLikedDesignsService(
            listResults: [
                .success(FeedListResponse(items: [makeFeedListItem(id: targetID, likeCount: 7)], nextCursor: nil))
            ],
            likeMode: .suspended
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)
        await viewModel.loadInitialFeed(force: true)

        viewModel.toggleLike(for: targetID)

        #expect(viewModel.items.isEmpty)

        service.completeLike(
            .success(FeedLikeResponse(ok: true, postId: targetID, isLiked: false, likeCount: 6))
        )

        await waitUntil {
            service.likeCallCount == 1
        }

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.likeErrorMessage == nil)
    }

    @Test
    func unlike_실패시_목록을롤백하고_에러를노출한다() async {
        let targetID = UUID()
        let service = MockLikedDesignsService(
            listResults: [
                .success(FeedListResponse(items: [makeFeedListItem(id: targetID, likeCount: 11)], nextCursor: nil))
            ],
            likeMode: .suspended
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)
        await viewModel.loadInitialFeed(force: true)

        viewModel.toggleLike(for: targetID)

        #expect(viewModel.items.isEmpty)

        service.completeLike(.failure(LikedDesignsMockError.forcedFailure))

        await waitUntil {
            viewModel.items.count == 1
        }

        #expect(viewModel.items.count == 1)
        if let restored = viewModel.items.first {
            #expect(restored.id == targetID)
            #expect(restored.isLiked == true)
        }
        #expect(viewModel.likeErrorMessage?.isEmpty == false)
    }

    @Test
    func 상세콜백에서_unlike되면_목록에서제거된다() async {
        let targetID = UUID()
        let service = MockLikedDesignsService(
            listResults: [
                .success(FeedListResponse(items: [makeFeedListItem(id: targetID, likeCount: 5)], nextCursor: nil))
            ]
        )
        let viewModel = LikedDesignsViewModel(pageSize: 20)
        viewModel.bind(service: service)
        await viewModel.loadInitialFeed(force: true)

        viewModel.applyLikeStateFromDetail(for: targetID, isLiked: false, likeCount: 4)

        #expect(viewModel.items.isEmpty)
    }

    private func makeFeedListItem(id: UUID, likeCount: Int, isLiked: Bool = true) -> FeedListItemResponse {
        FeedListItemResponse(
            id: id,
            thumbnailURL: "https://example.com/thumb.jpg",
            likeCount: likeCount,
            isReservable: false,
            isLiked: isLiked,
            styleTags: ["러블리/귀여움"],
            createdAt: Date()
        )
    }

    private func waitUntil(
        timeoutSeconds: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
    }
}

private enum LikedDesignsMockError: Error {
    case forcedFailure
    case missingResult
}

@MainActor
private final class MockLikedDesignsService: LikedDesignsServicing {
    enum LikeMode {
        case immediate(Result<FeedLikeResponse, Error>)
        case suspended
    }

    var listResults: [Result<FeedListResponse, Error>]
    var likeMode: LikeMode
    private(set) var likeCallCount: Int = 0
    private var continuation: CheckedContinuation<FeedLikeResponse, Error>?
    private var pendingLikeResult: Result<FeedLikeResponse, Error>?

    init(
        listResults: [Result<FeedListResponse, Error>],
        likeMode: LikeMode = .immediate(.success(FeedLikeResponse(ok: true, postId: UUID(), isLiked: false, likeCount: 0)))
    ) {
        self.listResults = listResults
        self.likeMode = likeMode
    }

    func fetchLikedFeedList(limit: Int, cursor: String?) async throws -> FeedListResponse {
        guard !listResults.isEmpty else {
            throw LikedDesignsMockError.forcedFailure
        }
        let result = listResults.removeFirst()
        return try result.get()
    }

    func setFeedLike(postId: UUID, isLiked: Bool) async throws -> FeedLikeResponse {
        likeCallCount += 1

        switch likeMode {
        case let .immediate(result):
            return try result.get()
        case .suspended:
            if let pendingLikeResult {
                self.pendingLikeResult = nil
                return try pendingLikeResult.get()
            }
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func completeLike(_ result: Result<FeedLikeResponse, Error>) {
        guard let continuation else {
            pendingLikeResult = result
            return
        }
        self.continuation = nil

        switch result {
        case let .success(response):
            continuation.resume(returning: response)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}
