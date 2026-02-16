//
//  HomeFeedItem.swift
//  NailClient
//

import Foundation

struct HomeFeedItem: Identifiable, Hashable {
    let id: UUID
    let imageName: String
    let likeCount: Int
    let shapeCategory: String
    let isReservable: Bool

    init(id: UUID = UUID(), imageName: String, likeCount: Int, shapeCategory: String, isReservable: Bool) {
        self.id = id
        self.imageName = imageName
        self.likeCount = likeCount
        self.shapeCategory = shapeCategory
        self.isReservable = isReservable
    }
}
