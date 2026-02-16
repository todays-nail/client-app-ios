//
//  FeedViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct FeedViewModelTests {

    @Test
    func toggleLike_처음누르면_좋아요증가및상태활성화() {
        let targetID = UUID()
        let viewModel = FeedViewModel(
            categories: ["전체"],
            items: [
                FeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    shapeCategory: "스퀘어",
                    isReservable: false
                )
            ]
        )

        viewModel.toggleLike(for: targetID)

        #expect(viewModel.items[0].isLiked == true)
        #expect(viewModel.items[0].likeCount == 11)
    }

    @Test
    func toggleLike_다시누르면_좋아요감소및상태해제() {
        let targetID = UUID()
        let viewModel = FeedViewModel(
            categories: ["전체"],
            items: [
                FeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    shapeCategory: "스퀘어",
                    isReservable: false,
                    isLiked: true
                )
            ]
        )

        viewModel.toggleLike(for: targetID)

        #expect(viewModel.items[0].isLiked == false)
        #expect(viewModel.items[0].likeCount == 9)
    }

    @Test
    func toggleLike_아이디없으면_변경되지않는다() {
        let targetID = UUID()
        let viewModel = FeedViewModel(
            categories: ["전체"],
            items: [
                FeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    shapeCategory: "스퀘어",
                    isReservable: false
                )
            ]
        )

        viewModel.toggleLike(for: UUID())

        #expect(viewModel.items[0].isLiked == false)
        #expect(viewModel.items[0].likeCount == 10)
    }

    @Test
    func toggleStyle_3개이하선택시_추가된다() {
        let viewModel = FeedViewModel()

        viewModel.toggleStyle(.natural)
        viewModel.toggleStyle(.french)

        #expect(viewModel.selectedStyles == [.natural, .french])
        #expect(viewModel.showMaxStyleAlert == false)
    }

    @Test
    func toggleStyle_이미선택된스타일탭시_해제된다() {
        let viewModel = FeedViewModel(selectedStyles: [.natural])

        viewModel.toggleStyle(.natural)

        #expect(viewModel.selectedStyles.isEmpty)
    }

    @Test
    func toggleStyle_3개선택후추가시도시_추가되지않고알럿플래그활성화() {
        let viewModel = FeedViewModel(selectedStyles: [.natural, .french, .wedding])

        viewModel.toggleStyle(.pointArt)

        #expect(viewModel.selectedStyles == [.natural, .french, .wedding])
        #expect(viewModel.showMaxStyleAlert == true)
    }

    @Test
    func handleStyleCategoryTap_스타일카테고리선택및시트오픈() {
        let viewModel = FeedViewModel(categories: ["전체", "스타일", "예약 가능 일정"])

        viewModel.handleStyleCategoryTap()

        #expect(viewModel.selectedCategory == "스타일")
        #expect(viewModel.isStylePickerPresented == true)
    }

    @Test
    func removeStyle_메인칩탭으로정상해제() {
        let viewModel = FeedViewModel(selectedStyles: [.natural, .french])

        viewModel.removeStyle(.natural)

        #expect(viewModel.selectedStyles == [.french])
    }

    @Test
    func handleScheduleCategoryTap_시트오픈되고카테고리즉시전환안함() {
        let viewModel = FeedViewModel(selectedCategory: "전체")

        viewModel.handleScheduleCategoryTap()

        #expect(viewModel.isSchedulePickerPresented == true)
        #expect(viewModel.selectedCategory == "전체")
    }

    @Test
    func applyScheduleSelectionAndActivateCategory_유효값이면카테고리전환및요약생성() {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let start = makeTime(hour: 14, minute: 0)
        let end = makeTime(hour: 16, minute: 0)
        let viewModel = FeedViewModel(
            selectedCategory: "전체",
            isSchedulePickerPresented: true,
            selectedReservationDate: option,
            selectedStartTime: start,
            selectedEndTime: end,
            reservationDateOptions: [option]
        )

        viewModel.applyScheduleSelectionAndActivateCategory()

        #expect(viewModel.selectedCategory == viewModel.scheduleCategoryName)
        #expect(viewModel.isSchedulePickerPresented == false)
        #expect(viewModel.reservationSummaryText == "2/20 14:00-16:00")
    }

    @Test
    func applyScheduleSelectionAndActivateCategory_종료가시작이하면알럿활성화() {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let start = makeTime(hour: 16, minute: 0)
        let end = makeTime(hour: 14, minute: 0)
        let viewModel = FeedViewModel(
            selectedCategory: "전체",
            isSchedulePickerPresented: true,
            selectedReservationDate: option,
            selectedStartTime: start,
            selectedEndTime: end,
            reservationDateOptions: [option]
        )

        viewModel.applyScheduleSelectionAndActivateCategory()

        #expect(viewModel.showInvalidScheduleAlert == true)
        #expect(viewModel.selectedCategory == "전체")
        #expect(viewModel.isSchedulePickerPresented == true)
    }

    @Test
    func clearScheduleSelection_요약및선택상태초기화() {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let viewModel = FeedViewModel(
            selectedReservationDate: option,
            selectedStartTime: makeTime(hour: 14, minute: 0),
            selectedEndTime: makeTime(hour: 16, minute: 0),
            reservationDateOptions: [option]
        )

        viewModel.clearScheduleSelection()

        #expect(viewModel.selectedReservationDate == nil)
        #expect(viewModel.selectedStartTime == nil)
        #expect(viewModel.selectedEndTime == nil)
        #expect(viewModel.reservationSummaryText == nil)
    }

    @Test
    func clearScheduleSelection_카테고리는유지된다() {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let viewModel = FeedViewModel(
            selectedCategory: "예약 가능 일정",
            selectedReservationDate: option,
            selectedStartTime: makeTime(hour: 14, minute: 0),
            selectedEndTime: makeTime(hour: 16, minute: 0),
            reservationDateOptions: [option]
        )

        viewModel.clearScheduleSelection()

        #expect(viewModel.selectedCategory == "예약 가능 일정")
    }

    @Test
    func reservationSummaryText_포맷이_koKR_형식으로생성() {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let viewModel = FeedViewModel(
            selectedReservationDate: option,
            selectedStartTime: makeTime(hour: 14, minute: 0),
            selectedEndTime: makeTime(hour: 16, minute: 0),
            reservationDateOptions: [option]
        )

        #expect(viewModel.reservationSummaryText == "2/20 14:00-16:00")
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date()
    }

    private func makeTime(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }
}
