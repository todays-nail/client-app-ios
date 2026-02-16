//
//  ReservationRepository.swift
//  NailClient
//

import Foundation

protocol ReservationRepository {
    func fetchUpcoming() async throws -> [UpcomingReservation]
    func fetchPast(page: Int, pageSize: Int) async throws -> ReservationPage<PastReservation>
}
