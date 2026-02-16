//
//  ReservationMockRepository.swift
//  NailClient
//

import Foundation

enum ReservationMockRepositoryError: Error {
    case invalidPaging
    case forcedFailure
}

struct ReservationMockRepository: ReservationRepository {
    private let upcomingItems: [UpcomingReservation]
    private let pastItems: [PastReservation]
    private let shouldFailUpcoming: Bool
    private let shouldFailPast: Bool

    init(
        upcomingItems: [UpcomingReservation] = ReservationMockData.upcoming(),
        pastItems: [PastReservation] = ReservationMockData.past(),
        shouldFailUpcoming: Bool = false,
        shouldFailPast: Bool = false
    ) {
        self.upcomingItems = upcomingItems
        self.pastItems = pastItems
        self.shouldFailUpcoming = shouldFailUpcoming
        self.shouldFailPast = shouldFailPast
    }

    func fetchUpcoming() async throws -> [UpcomingReservation] {
        if shouldFailUpcoming {
            throw ReservationMockRepositoryError.forcedFailure
        }
        return upcomingItems
    }

    func fetchPast(page: Int, pageSize: Int) async throws -> ReservationPage<PastReservation> {
        guard page >= 0, pageSize > 0 else {
            throw ReservationMockRepositoryError.invalidPaging
        }

        if shouldFailPast {
            throw ReservationMockRepositoryError.forcedFailure
        }

        let start = page * pageSize
        guard start < pastItems.count else {
            return ReservationPage(items: [], hasNext: false)
        }

        let end = min(start + pageSize, pastItems.count)
        let pageItems = Array(pastItems[start..<end])
        let hasNext = end < pastItems.count
        return ReservationPage(items: pageItems, hasNext: hasNext)
    }
}
