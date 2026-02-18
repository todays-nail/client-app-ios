//
//  AppUser.swift
//  NailClient
//

import Foundation

struct AppUser: Codable, Sendable {
    let id: UUID
    let role: String?
    let nickname: String?
    let profileImageURL: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case nickname
        case profileImageURL = "profile_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
