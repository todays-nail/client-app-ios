#if false
//
//  FeedRecentNeighborhoodStoreTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

struct FeedRecentNeighborhoodStoreTests {
    @Test
    func load_무효값중복을제거하고_최대두개만반환한다() {
        let (suiteName, defaults, key) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let secondID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let thirdID = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!

        defaults.set(
            [
                "not-a-uuid",
                firstID.uuidString.lowercased(),
                secondID.uuidString.lowercased(),
                secondID.uuidString.lowercased(),
                thirdID.uuidString.lowercased(),
            ],
            forKey: key
        )

        let store = FeedRecentNeighborhoodStore(userDefaults: defaults, key: key)
        let loaded = store.load()

        #expect(loaded == [firstID, secondID])
    }

    @Test
    func save_중복제거후_최대두개까지만저장한다() {
        let (suiteName, defaults, key) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let thirdID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!

        let store = FeedRecentNeighborhoodStore(userDefaults: defaults, key: key)
        store.save([firstID, secondID, firstID, thirdID])

        let loaded = store.load()
        #expect(loaded == [firstID, secondID])
    }

    @Test
    func clear_저장값을삭제한다() {
        let (suiteName, defaults, key) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let store = FeedRecentNeighborhoodStore(userDefaults: defaults, key: key)
        store.save([firstID])

        store.clear()

        #expect(store.load().isEmpty)
    }

    private func makeIsolatedDefaults() -> (suiteName: String, defaults: UserDefaults, key: String) {
        let suiteName = "FeedRecentNeighborhoodStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("테스트 전용 UserDefaults를 생성하지 못했습니다.")
        }
        let key = "feed_recent_neighborhood_ids_test"
        defaults.removeObject(forKey: key)
        return (suiteName, defaults, key)
    }
}

#endif
