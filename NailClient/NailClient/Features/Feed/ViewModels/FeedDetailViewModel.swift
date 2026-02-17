//
//  FeedDetailViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class FeedDetailViewModel: ObservableObject {
    @Published private(set) var detail: FeedDetail?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var likeErrorMessage: String?
    @Published private(set) var isLiked: Bool
    @Published private(set) var likeCount: Int
    @Published private(set) var isLikeUpdating: Bool = false

    let item: FeedItem

    private weak var service: (any FeedServicing)?
    private var didLoad: Bool = false

    var isInitialLoading: Bool {
        isLoading && detail == nil
    }

    init(item: FeedItem, service: (any FeedServicing)? = nil) {
        self.item = item
        self.service = service
        self.isLiked = item.isLiked
        self.likeCount = item.likeCount
    }

    func bind(service: any FeedServicing) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        await load(force: false)
    }

    func reload() async {
        await load(force: true)
    }

    func toggleLikeLocal() {
        if isLiked {
            likeCount = max(0, likeCount - 1)
        } else {
            likeCount += 1
        }
        isLiked.toggle()
    }

    func toggleLike() async -> FeedLikeResponse? {
        guard !isLikeUpdating else { return nil }
        likeErrorMessage = nil

        let previousState = (isLiked: isLiked, likeCount: likeCount)
        toggleLikeLocal()

        guard let service else {
            return FeedLikeResponse(ok: true, postId: item.id, isLiked: isLiked, likeCount: likeCount)
        }

        isLikeUpdating = true
        defer { isLikeUpdating = false }

        do {
            let response = try await service.setFeedLike(postId: item.id, isLiked: isLiked)
            isLiked = response.isLiked
            likeCount = max(0, response.likeCount)
            return response
        } catch {
            isLiked = previousState.isLiked
            likeCount = previousState.likeCount
            likeErrorMessage = "좋아요 반영에 실패했어요. 잠시 후 다시 시도해 주세요."
            return nil
        }
    }

    private func load(force: Bool) async {
        guard let service else { return }
        if isLoading { return }
        if didLoad && !force { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchFeedDetail(postId: item.id)
            detail = mapDetail(from: response)
            isLiked = response.post.isLiked
            likeCount = response.post.likeCount
            didLoad = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func mapDetail(from response: FeedDetailResponse) -> FeedDetail {
        let galleryURLs = response.galleryImageURLs.compactMap(URL.init(string:))

        let reviews: [FeedReview] = response.recentReviews.map { review in
            FeedReview(
                id: UUID(),
                userName: review.userName,
                rating: review.rating,
                comment: review.comment,
                createdAt: review.createdAt
            )
        }

        return FeedDetail(
            id: response.post.id,
            title: response.post.title,
            thumbnailURL: URL(string: response.post.thumbnailURL),
            shopId: response.post.shopId,
            likeCount: response.post.likeCount,
            shapeCategory: response.post.shapeCategory,
            isReservable: response.post.isReservable,
            isLiked: response.post.isLiked,
            styleTags: response.post.styleTags,
            studioName: response.post.studioName,
            locationText: response.post.locationText,
            distanceKM: response.post.distanceKM,
            originalPrice: response.post.originalPrice,
            discountedPrice: response.post.discountedPrice,
            durationMin: response.post.durationMin,
            description: response.post.description,
            reviewCount: response.post.reviewCount,
            ratingAvg: response.post.ratingAvg,
            galleryImageURLs: galleryURLs,
            recentReviews: reviews
        )
    }
}
