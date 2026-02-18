//
//  FeedRecentNeighborhoodStore.swift
//  NailClient
//

import Foundation

protocol FeedRecentNeighborhoodStoring: AnyObject {
    func load() -> [UUID]
    func save(_ ids: [UUID])
    func clear()
}

final class FeedRecentNeighborhoodStore: FeedRecentNeighborhoodStoring {
    private let userDefaults: UserDefaults
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "feed_recent_neighborhood_ids_v1"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func load() -> [UUID] {
        guard let rawIDs = userDefaults.array(forKey: key) as? [String] else {
            return []
        }

        let sanitized = sanitize(rawIDs: rawIDs)
        if sanitized.map({ $0.uuidString.lowercased() }) != rawIDs {
            userDefaults.set(sanitized.map({ $0.uuidString.lowercased() }), forKey: key)
        }
        return sanitized
    }

    func save(_ ids: [UUID]) {
        let normalized = sanitize(ids: ids)
        userDefaults.set(normalized.map({ $0.uuidString.lowercased() }), forKey: key)
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }

    private func sanitize(rawIDs: [String]) -> [UUID] {
        let parsed = rawIDs.compactMap(UUID.init(uuidString:))
        return sanitize(ids: parsed)
    }

    private func sanitize(ids: [UUID]) -> [UUID] {
        var unique: [UUID] = []
        var seen: Set<UUID> = []

        for id in ids where seen.insert(id).inserted {
            unique.append(id)
            if unique.count == 2 {
                break
            }
        }

        return unique
    }
}
