//
//  FeedRegionPreferenceStore.swift
//  NailClient
//

import Foundation

protocol FeedRegionPreferenceStoring: AnyObject {
    func load() -> FeedRegionPreference?
    func save(_ preference: FeedRegionPreference)
    func clear()
}

enum FeedRegionPreference: Equatable, Sendable {
    case all
    case region(UUID)
}

final class FeedRegionPreferenceStore: FeedRegionPreferenceStoring {
    private let userDefaults: UserDefaults
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "feed_region_preference_v1"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func load() -> FeedRegionPreference? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            switch payload.kind {
            case Payload.Kind.all.rawValue:
                return .all
            case Payload.Kind.region.rawValue:
                guard
                    let regionIDRaw = payload.regionID,
                    let regionID = UUID(uuidString: regionIDRaw)
                else {
                    return nil
                }
                return .region(regionID)
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    func save(_ preference: FeedRegionPreference) {
        let payload: Payload

        switch preference {
        case .all:
            payload = Payload(kind: Payload.Kind.all.rawValue, regionID: nil)
        case let .region(regionID):
            payload = Payload(kind: Payload.Kind.region.rawValue, regionID: regionID.uuidString.lowercased())
        }

        guard let encoded = try? JSONEncoder().encode(payload) else {
            return
        }

        userDefaults.set(encoded, forKey: key)
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }
}

private struct Payload: Codable {
    enum Kind: String {
        case all
        case region
    }

    let kind: String
    let regionID: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case regionID = "region_id"
    }
}
