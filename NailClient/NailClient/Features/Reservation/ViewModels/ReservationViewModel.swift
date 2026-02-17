//
//  ReservationViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class ReservationViewModel: ObservableObject {
    @Published var selectedSegment: ReservationSegment = .upcoming
    @Published private(set) var upcoming: [UpcomingReservation] = []
    @Published private(set) var past: [PastReservation] = []

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var hasMorePast: Bool = false

    @Published var alertMessage: String?
    @Published var route: ReservationRoute?

    private var repository: any ReservationRepository
    private let pastPageSize: Int

    private var didLoad: Bool = false
    private var currentPastPage: Int = 0

    init(
        repository: (any ReservationRepository)? = nil,
        pastPageSize: Int = 3
    ) {
        self.repository = repository ?? ReservationMockRepository()
        self.pastPageSize = max(1, pastPageSize)
    }

    func bind(repository: any ReservationRepository) {
        self.repository = repository
    }

    func onAppear() {
        guard !didLoad else { return }
        didLoad = true
        isLoading = true

        Task {
            await loadInitial()
        }
    }

    func selectSegment(_ segment: ReservationSegment) {
        selectedSegment = segment
    }

    func tapChangeReservation(_ reservation: UpcomingReservation) {
        route = .changeReservation(reservation)
    }

    func tapDirections(_ reservation: UpcomingReservation) {
        route = .directions(reservation)
    }

    func tapWriteReview(_ reservation: PastReservation) {
        route = .writeReview(reservation)
    }

    func dismissRoute() {
        route = nil
    }

    func clearAlertMessage() {
        alertMessage = nil
    }

    func refresh() {
        guard !isLoading, !isLoadingMore else { return }
        didLoad = false
        currentPastPage = 0
        hasMorePast = false
        upcoming = []
        past = []
        onAppear()
    }

    func loadMorePastIfNeeded(currentItem: PastReservation?) {
        guard !isLoading, !isLoadingMore, hasMorePast else { return }

        if let currentItem {
            guard currentItem.id == past.last?.id else { return }
        }

        isLoadingMore = true
        Task {
            await loadMorePast()
        }
    }

    private func loadInitial() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedUpcoming = repository.fetchUpcoming()
            async let firstPastPage = repository.fetchPast(page: 0, pageSize: pastPageSize)
            let (upcomingItems, pastPage) = try await (fetchedUpcoming, firstPastPage)

            upcoming = upcomingItems
            past = pastPage.items
            currentPastPage = 0
            hasMorePast = pastPage.hasNext
        } catch {
            alertMessage = "예약 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            hasMorePast = false
        }
    }

    private func loadMorePast() async {
        defer { isLoadingMore = false }

        do {
            let nextPage = currentPastPage + 1
            let next = try await repository.fetchPast(page: nextPage, pageSize: pastPageSize)

            past.append(contentsOf: next.items)
            currentPastPage = nextPage
            hasMorePast = next.hasNext
        } catch {
            hasMorePast = false
            alertMessage = "지난 예약을 더 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}
