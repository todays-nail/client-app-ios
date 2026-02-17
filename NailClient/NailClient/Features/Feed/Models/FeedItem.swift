//
//  FeedItem.swift
//  NailClient
//

import Foundation

struct FeedItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let thumbnailURL: URL?
    let fallbackAssetName: String
    var likeCount: Int
    let shapeCategory: String
    let isReservable: Bool
    var isLiked: Bool
    let styleTags: [String]
    let createdAt: Date?

    var imageName: String { fallbackAssetName }

    init(
        id: UUID = UUID(),
        imageName: String,
        likeCount: Int,
        shapeCategory: String,
        isReservable: Bool,
        isLiked: Bool = false,
        thumbnailURL: URL? = nil,
        styleTags: [String] = [],
        createdAt: Date? = nil
    ) {
        self.id = id
        self.thumbnailURL = thumbnailURL
        self.fallbackAssetName = imageName
        self.likeCount = likeCount
        self.shapeCategory = shapeCategory
        self.isReservable = isReservable
        self.isLiked = isLiked
        self.styleTags = styleTags
        self.createdAt = createdAt
    }

    init(
        id: UUID,
        thumbnailURL: URL?,
        fallbackAssetName: String,
        likeCount: Int,
        shapeCategory: String,
        isReservable: Bool,
        isLiked: Bool,
        styleTags: [String],
        createdAt: Date?
    ) {
        self.id = id
        self.thumbnailURL = thumbnailURL
        self.fallbackAssetName = fallbackAssetName
        self.likeCount = likeCount
        self.shapeCategory = shapeCategory
        self.isReservable = isReservable
        self.isLiked = isLiked
        self.styleTags = styleTags
        self.createdAt = createdAt
    }
}

struct FeedDetail: Sendable, Equatable {
    let id: UUID
    let title: String
    let thumbnailURL: URL?
    let shopId: UUID?
    let likeCount: Int
    let shapeCategory: String
    let isReservable: Bool
    let isLiked: Bool
    let styleTags: [String]
    let studioName: String
    let locationText: String
    let distanceKM: Double?
    let originalPrice: Int
    let discountedPrice: Int
    let durationMin: Int
    let description: String
    let reviewCount: Int
    let ratingAvg: Double
    let galleryImageURLs: [URL]
    let recentReviews: [FeedReview]
}

struct FeedReview: Identifiable, Sendable, Equatable {
    let id: UUID
    let userName: String
    let rating: Int
    let comment: String
    let createdAt: Date

    init(id: UUID = UUID(), userName: String, rating: Int, comment: String, createdAt: Date) {
        self.id = id
        self.userName = userName
        self.rating = rating
        self.comment = comment
        self.createdAt = createdAt
    }
}
