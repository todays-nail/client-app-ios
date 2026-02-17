//
//  ShopModels.swift
//  NailClient
//

import Foundation

struct ShopSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let address: String
}

struct ShopRecommendation: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let likeCount: Int
}

enum ShopRecommendationScope: String, Sendable {
    case region
    case nationwide
}

struct ShopRegion: Hashable, Sendable {
    let sido: String
    let sigungu: String?

    var displayName: String {
        if let sigungu, !sigungu.isEmpty {
            return "\(sido) \(sigungu)"
        }
        return sido
    }
}

struct ShopDetail: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let addressDetail: String?
    let phone: String?
    let status: String
    let intro: String?
    let openTime: String?
    let closeTime: String?
    let closedWeekdays: [String]
}
