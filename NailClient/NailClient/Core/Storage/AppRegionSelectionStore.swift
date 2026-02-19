import Foundation

struct AppRegionSelection: Equatable, Sendable {
    let currentRegionID: UUID?
    let recentRegionID: UUID?
}

protocol AppRegionSelectionStoring: AnyObject {
    func loadSelection() -> AppRegionSelection
    func setCurrentRegion(_ regionID: UUID)
    func setRecentRegion(_ regionID: UUID)
    func clear()
}

final class AppRegionSelectionStore: AppRegionSelectionStoring {
    private enum Keys {
        static let current = "app_current_region_id_v1"
        static let recent = "app_recent_region_id_v1"
        static let migrated = "app_region_selection_migrated_v1"
        static let legacyPreference = "feed_region_preference_v1"
        static let legacyRecents = "feed_recent_neighborhood_ids_v1"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        migrateLegacyIfNeeded()
    }

    func loadSelection() -> AppRegionSelection {
        AppRegionSelection(
            currentRegionID: loadUUID(forKey: Keys.current),
            recentRegionID: loadUUID(forKey: Keys.recent)
        )
    }

    func setCurrentRegion(_ regionID: UUID) {
        var selection = loadSelection()
        if selection.currentRegionID != regionID {
            selection = AppRegionSelection(
                currentRegionID: regionID,
                recentRegionID: selection.currentRegionID == regionID ? selection.recentRegionID : selection.currentRegionID
            )
        }

        saveUUID(selection.currentRegionID, forKey: Keys.current)
        saveUUID(selection.recentRegionID, forKey: Keys.recent)
    }

    func setRecentRegion(_ regionID: UUID) {
        let selection = loadSelection()
        guard selection.currentRegionID != regionID else {
            return
        }

        saveUUID(regionID, forKey: Keys.recent)
    }

    func clear() {
        userDefaults.removeObject(forKey: Keys.current)
        userDefaults.removeObject(forKey: Keys.recent)
    }

    private func migrateLegacyIfNeeded() {
        guard userDefaults.bool(forKey: Keys.migrated) == false else {
            return
        }

        let currentRegionID = loadUUID(forKey: Keys.current) ?? loadLegacyCurrentRegionID()
        let recentRegionID = loadUUID(forKey: Keys.recent) ?? loadLegacyRecentRegionID(excluding: currentRegionID)

        saveUUID(currentRegionID, forKey: Keys.current)
        saveUUID(recentRegionID, forKey: Keys.recent)
        userDefaults.set(true, forKey: Keys.migrated)
    }

    private func loadUUID(forKey key: String) -> UUID? {
        guard let raw = userDefaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let uuid = UUID(uuidString: raw) else {
            return nil
        }
        return uuid
    }

    private func saveUUID(_ uuid: UUID?, forKey key: String) {
        if let uuid {
            userDefaults.set(uuid.uuidString.lowercased(), forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func loadLegacyCurrentRegionID() -> UUID? {
        guard let data = userDefaults.data(forKey: Keys.legacyPreference) else {
            return nil
        }

        guard let payload = try? JSONDecoder().decode(LegacyPreferencePayload.self, from: data) else {
            return nil
        }

        guard payload.kind == "region",
              let rawID = payload.regionID,
              let uuid = UUID(uuidString: rawID) else {
            return nil
        }

        return uuid
    }

    private func loadLegacyRecentRegionID(excluding currentRegionID: UUID?) -> UUID? {
        guard let rawIDs = userDefaults.array(forKey: Keys.legacyRecents) as? [String] else {
            return nil
        }

        for rawID in rawIDs {
            guard let uuid = UUID(uuidString: rawID) else { continue }
            if uuid != currentRegionID {
                return uuid
            }
        }

        return nil
    }
}

private struct LegacyPreferencePayload: Decodable {
    let kind: String
    let regionID: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case regionID = "region_id"
    }
}
