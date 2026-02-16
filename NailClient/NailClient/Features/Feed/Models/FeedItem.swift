//
//  FeedItem.swift
//  NailClient
//

import Foundation

struct FeedItem: Identifiable, Hashable {
    let id: UUID
    let imageName: String
    var likeCount: Int
    let shapeCategory: String
    let isReservable: Bool
    var isLiked: Bool

    init(
        id: UUID = UUID(),
        imageName: String,
        likeCount: Int,
        shapeCategory: String,
        isReservable: Bool,
        isLiked: Bool = false
    ) {
        self.id = id
        self.imageName = imageName
        self.likeCount = likeCount
        self.shapeCategory = shapeCategory
        self.isReservable = isReservable
        self.isLiked = isLiked
    }
}
