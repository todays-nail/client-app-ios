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

    init(id: UUID = UUID(), imageName: String, likeCount: Int, shapeCategory: String) {
        self.id = id
        self.imageName = imageName
        self.likeCount = likeCount
        self.shapeCategory = shapeCategory
    }
}
