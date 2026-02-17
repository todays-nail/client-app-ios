//
//  ReservationRepository.swift
//  NailClient
//

import Foundation

protocol ReservationRepository {
    func fetchUpcoming() async throws -> [UpcomingReservation]
    func fetchPast(page: Int, pageSize: Int) async throws -> ReservationPage<PastReservation>
}

@MainActor
protocol ReservationServicing: AnyObject {
    func fetchReservationSlots(
        referenceId: UUID,
        fromDate: String,
        days: Int
    ) async throws -> ReservationSlotsResponse

    func createReservation(
        referenceId: UUID,
        slotId: UUID,
        selectedOptionsSnapshot: [String: Int]?,
        attachedImageURL: String?,
        aiGenerationId: UUID?
    ) async throws -> ReservationCreateResponse

    func fetchReservationList(
        segment: ReservationListSegment,
        limit: Int,
        cursor: String?
    ) async throws -> ReservationListResponse
}

extension AppViewModel: ReservationServicing {}
