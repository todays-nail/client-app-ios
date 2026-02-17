//
//  FeedRegionAutoSelector.swift
//  NailClient
//

import Foundation

struct FeedRegionAutoSelection: Equatable, Sendable {
    let city: FeedRegion
    let district: FeedRegion?

    var regionID: UUID {
        district?.id ?? city.id
    }
}

@MainActor
final class FeedRegionAutoSelector {
    private let regionProvider: any CurrentRegionProviding

    init(regionProvider: (any CurrentRegionProviding)? = nil) {
        self.regionProvider = regionProvider ?? CurrentRegionProvider()
    }

    func select(
        from cities: [FeedRegion],
        districtsByCityID: [UUID: [FeedRegion]]
    ) async -> FeedRegionAutoSelection? {
        let resolution = await regionProvider.fetchCurrentRegion()
        guard case let .resolved(currentRegion) = resolution else {
            return nil
        }

        guard let matchedCity = cities.first(where: {
            Self.normalizeCityName($0.name) == Self.normalizeCityName(currentRegion.sido)
        }) else {
            return nil
        }

        let matchedDistrict = districtsByCityID[matchedCity.id]?.first(where: {
            Self.normalizeDistrictName($0.name) == Self.normalizeDistrictName(currentRegion.sigungu)
        })

        return FeedRegionAutoSelection(city: matchedCity, district: matchedDistrict)
    }

    private static func normalizeCityName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "특별시", with: "")
            .replacingOccurrences(of: "광역시", with: "")
            .replacingOccurrences(of: "특별자치시", with: "")
            .replacingOccurrences(of: "특별자치도", with: "")
            .replacingOccurrences(of: "도", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeDistrictName(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
