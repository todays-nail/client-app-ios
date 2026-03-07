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
    let defaultRegionID: UUID?
    let defaultRegionLabel: String?
    let defaultServiceRegionID: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case nickname
        case profileImageURL = "profile_image_url"
        case defaultRegionID = "default_region_id"
        case defaultRegionLabel = "default_region_label"
        case defaultServiceRegionID = "default_service_region_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

#if DEBUG
extension AppUser {
    nonisolated static func preview(
        id: UUID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
        role: String? = nil,
        nickname: String? = "프리뷰 사용자",
        profileImageURL: String? = nil
    ) -> AppUser {
        AppUser(
            id: id,
            role: role,
            nickname: nickname,
            profileImageURL: profileImageURL,
            defaultRegionID: nil,
            defaultRegionLabel: nil,
            defaultServiceRegionID: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
#endif
