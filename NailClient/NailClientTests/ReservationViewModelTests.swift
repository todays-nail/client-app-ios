#if false
//
//  ReservationViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct ReservationViewModelTests {
    @Test
    func onAppear_초기로드_성공시_예약목록을설정한다() async {
        let upcomingItems = makeUpcomingItems()
        let pastItems = makePastItems()

        let repository = ReservationRepositorySpy(
            upcomingResult: .success(upcomingItems),
            pastPages: [
                0: .success(ReservationPage(items: Array(pastItems.prefix(2)), hasNext: true))
            ]
        )

        let viewModel = ReservationViewModel(repository: repository, pastPageSize: 2)
        viewModel.onAppear()

        await waitUntil { !viewModel.isLoading }

        #expect(viewModel.upcoming == upcomingItems)
        #expect(viewModel.past == Array(pastItems.prefix(2)))
        #expect(viewModel.hasMorePast == true)
        #expect(await repository.upcomingCallCount() == 1)
        #expect(await repository.requestedPages() == [0])
    }

    @Test
    func 세그먼트_전환시_selectedSegment가_변경된다() {
        let viewModel = ReservationViewModel(repository: ReservationRepositorySpy())

        #expect(viewModel.selectedSegment == .upcoming)
        viewModel.selectSegment(.past)
        #expect(viewModel.selectedSegment == .past)
    }

    @Test
    func pastPagination_중복호출을_방지한다() async {
        let pastItems = makePastItems()

        let repository = ReservationRepositorySpy(
            upcomingResult: .success(makeUpcomingItems()),
            pastPages: [
                0: .success(ReservationPage(items: Array(pastItems.prefix(2)), hasNext: true)),
                1: .success(ReservationPage(items: [pastItems[2]], hasNext: false))
            ]
        )

        let viewModel = ReservationViewModel(repository: repository, pastPageSize: 2)
        viewModel.onAppear()
        await waitUntil { !viewModel.isLoading }

        let firstItem = viewModel.past[0]
        viewModel.loadMorePastIfNeeded(currentItem: firstItem)
        await Task.yield()
        #expect(await repository.requestedPages() == [0])

        let lastItem = viewModel.past[1]
        viewModel.loadMorePastIfNeeded(currentItem: lastItem)
        viewModel.loadMorePastIfNeeded(currentItem: lastItem)

        await waitUntil { !viewModel.isLoadingMore }

        #expect(await repository.requestedPages() == [0, 1])
        #expect(viewModel.past.count == 3)
        #expect(viewModel.hasMorePast == false)
    }

    @Test
    func 저장소오류시_alertMessage를_설정한다() async {
        let repository = ReservationRepositorySpy(
            upcomingResult: .failure(TestRepositoryError.failed),
            pastPages: [:]
        )

        let viewModel = ReservationViewModel(repository: repository)
        viewModel.onAppear()

        await waitUntil { !viewModel.isLoading }

        #expect(viewModel.alertMessage != nil)
        #expect(viewModel.upcoming.isEmpty)
    }

    @Test
    func CTA_탭시_올바른_route를_설정한다() {
        let viewModel = ReservationViewModel(repository: ReservationRepositorySpy())
        let upcomingItem = makeUpcomingItems()[0]
        let pastItem = makePastItems()[0]

        viewModel.tapChangeReservation(upcomingItem)
        #expect(viewModel.route == .changeReservation(upcomingItem))

        viewModel.tapDirections(upcomingItem)
        #expect(viewModel.route == .directions(upcomingItem))

        viewModel.tapWriteReview(pastItem)
        #expect(viewModel.route == .writeReview(pastItem))
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let started = clock.now

        while !condition() {
            if started.duration(to: clock.now) > timeout {
                break
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func makeUpcomingItems() -> [UpcomingReservation] {
        ReservationMockData.upcoming(now: Date(timeIntervalSince1970: 1_736_000_000))
    }

    private func makePastItems() -> [PastReservation] {
        ReservationMockData.past(now: Date(timeIntervalSince1970: 1_736_000_000))
    }
}

private enum TestRepositoryError: Error {
    case failed
}

private actor ReservationRepositorySpy: ReservationRepository {
    private let upcomingResult: Result<[UpcomingReservation], Error>
    private let pastPages: [Int: Result<ReservationPage<PastReservation>, Error>]

    private var upcomingCalls: Int = 0
    private var pastCallPages: [Int] = []

    init(
        upcomingResult: Result<[UpcomingReservation], Error> = .success([]),
        pastPages: [Int: Result<ReservationPage<PastReservation>, Error>] = [:]
    ) {
        self.upcomingResult = upcomingResult
        self.pastPages = pastPages
    }

    func fetchUpcoming() async throws -> [UpcomingReservation] {
        upcomingCalls += 1
        return try upcomingResult.get()
    }

    func fetchPast(page: Int, pageSize: Int) async throws -> ReservationPage<PastReservation> {
        pastCallPages.append(page)

        if let result = pastPages[page] {
            return try result.get()
        }

        return ReservationPage(items: [], hasNext: false)
    }

    func upcomingCallCount() -> Int {
        upcomingCalls
    }

    func requestedPages() -> [Int] {
        pastCallPages
    }
}

#endif
