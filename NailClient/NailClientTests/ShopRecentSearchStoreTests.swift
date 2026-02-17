//
//  ShopRecentSearchStoreTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

struct ShopRecentSearchStoreTests {
    @Test
    func 중복제거와최신정렬을유지한다() {
        let suiteName = "ShopRecentSearchStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = ShopRecentSearchStore(userDefaults: defaults, key: "recent", maxCount: 10)

        store.save(query: "강남 네일")
        store.save(query: "역삼 네일")
        store.save(query: "강남 네일")

        #expect(store.loadRecentSearches() == ["강남 네일", "역삼 네일"])
    }

    @Test
    func 최대10개로제한된다() {
        let suiteName = "ShopRecentSearchStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = ShopRecentSearchStore(userDefaults: defaults, key: "recent", maxCount: 10)

        for idx in 1...12 {
            store.save(query: "q\(idx)")
        }

        let values = store.loadRecentSearches()
        #expect(values.count == 10)
        #expect(values.first == "q12")
        #expect(values.last == "q3")
    }

    @Test
    func remove와clear가동작한다() {
        let suiteName = "ShopRecentSearchStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = ShopRecentSearchStore(userDefaults: defaults, key: "recent", maxCount: 10)

        store.save(query: "강남 네일")
        store.save(query: "역삼 네일")

        store.remove(query: "강남 네일")
        #expect(store.loadRecentSearches() == ["역삼 네일"])

        store.clear()
        #expect(store.loadRecentSearches().isEmpty)
    }
}
