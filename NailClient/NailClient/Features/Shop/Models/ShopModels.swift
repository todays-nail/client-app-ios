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
