//
//  ShopRecentSearchStore.swift
//  NailClient
//

import Foundation

protocol ShopRecentSearchStoring: AnyObject {
    func loadRecentSearches() -> [String]
    func save(query: String)
    func remove(query: String)
    func clear()
}

final class ShopRecentSearchStore: ShopRecentSearchStoring {
    private let userDefaults: UserDefaults
    private let key: String
    private let maxCount: Int

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "shop_recent_searches_v1",
        maxCount: Int = 10
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.maxCount = max(1, maxCount)
    }

    func loadRecentSearches() -> [String] {
        guard let values = userDefaults.array(forKey: key) as? [String] else {
            return []
        }
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func save(query: String) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        var values = loadRecentSearches()
        values.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        values.insert(normalized, at: 0)

        if values.count > maxCount {
            values = Array(values.prefix(maxCount))
        }

        userDefaults.set(values, forKey: key)
    }

    func remove(query: String) {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        let values = loadRecentSearches().filter {
            $0.caseInsensitiveCompare(normalized) != .orderedSame
        }
        userDefaults.set(values, forKey: key)
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }
}
