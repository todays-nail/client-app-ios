//
//  HomeMockData.swift
//  NailClient
//

import Foundation

enum HomeMockData {
    static let promoTitle: String = "고민말고,\nAI로 미리보기"
    static let promoDescription: String = "내 손에 어울리는 디자인을\n3초 만에 확인해보세요."
    static let promoImageName: String = "natural"

    static let categories: [String] = [
        "전체",
        "아몬드",
        "스퀘어",
        "라운드",
        "발레리나"
    ]

    static let feedItems: [HomeFeedItem] = [
        HomeFeedItem(imageName: "natural", likeCount: 128, shapeCategory: "스퀘어"),
        HomeFeedItem(imageName: "chic_modern", likeCount: 245, shapeCategory: "아몬드"),
        HomeFeedItem(imageName: "french", likeCount: 89, shapeCategory: "라운드"),
        HomeFeedItem(imageName: "glitter_pearl", likeCount: 156, shapeCategory: "아몬드"),
        HomeFeedItem(imageName: "lovely", likeCount: 312, shapeCategory: "스퀘어"),
        HomeFeedItem(imageName: "hip", likeCount: 198, shapeCategory: "아몬드"),
        HomeFeedItem(imageName: "wedding", likeCount: 42, shapeCategory: "발레리나"),
        HomeFeedItem(imageName: "point-art", likeCount: 220, shapeCategory: "라운드"),
        HomeFeedItem(imageName: "kitsh_unique", likeCount: 175, shapeCategory: "스퀘어")
    ]
}
