//
//  FeedRegion.swift
//  NailClient
//

import Foundation

struct FeedRegion: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let parentID: UUID?
    let level: Int?
}
