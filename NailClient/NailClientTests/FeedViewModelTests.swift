#if false
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
                    isReservable: false
                )
            ]
        )

        viewModel.toggleLike(for: UUID())

        #expect(viewModel.items[0].isLiked == false)
        #expect(viewModel.items[0].likeCount == 10)
    }

    @Test
    func toggleLike_서버성공응답이면_서버상태로동기화된다() async {
        let targetID = UUID()
        let service = MockFeedService(
            listResults: [],
            likeResults: [
                .success(FeedLikeResponse(ok: true, postId: targetID, isLiked: true, likeCount: 42))
            ]
        )
        let viewModel = FeedViewModel(
            categories: ["전체"],
            items: [
                FeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    isReservable: false
                )
            ],
            service: service
        )

        viewModel.toggleLike(for: targetID)
        await waitUntil { viewModel.items[0].likeCount == 42 }

        #expect(viewModel.items[0].isLiked == true)
        #expect(viewModel.items[0].likeCount == 42)
        #expect(viewModel.likeErrorMessage == nil)
    }

    @Test
    func toggleLike_서버실패하면_롤백되고에러메시지노출() async {
        let targetID = UUID()
        let service = MockFeedService(
            listResults: [],
            likeResults: [
                .failure(FeedMockServiceError.forcedFailure)
            ]
        )
        let viewModel = FeedViewModel(
            categories: ["전체"],
            items: [
                FeedItem(
                    id: targetID,
                    imageName: "natural",
                    likeCount: 10,
                    isReservable: false
                )
            ],
            service: service
        )

        viewModel.toggleLike(for: targetID)
        await waitUntil { viewModel.items[0].isLiked == false }

        #expect(viewModel.items[0].isLiked == false)
        #expect(viewModel.items[0].likeCount == 10)
        #expect(viewModel.likeErrorMessage?.isEmpty == false)
    }

    @Test
    func 초기화_서비스없으면_mock아이템자동주입하지않는다() {
        let viewModel = FeedViewModel()

        #expect(viewModel.items.isEmpty)
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
    func selectCategory_전체선택시_스타일만초기화되고예약값은유지된다() {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let viewModel = FeedViewModel(
            selectedCategory: "스타일",
            selectedStyles: [.natural, .french],
            selectedReservationDate: option,
            selectedStartTime: makeTime(hour: 14, minute: 0),
            selectedEndTime: makeTime(hour: 16, minute: 0),
            reservationDateOptions: [option]
        )

        viewModel.selectCategory("전체")

        #expect(viewModel.selectedCategory == "전체")
        #expect(viewModel.selectedStyles.isEmpty)
        #expect(viewModel.selectedReservationDate == option)
        #expect(viewModel.reservationSummaryText == "2/20 14:00-16:00")
    }

    @Test
    func selectCategory_이미전체여도_스타일선택이남아있으면초기화된다() {
        let viewModel = FeedViewModel(
            selectedCategory: "전체",
            selectedStyles: [.natural]
        )

        viewModel.selectCategory("전체")

        #expect(viewModel.selectedCategory == "전체")
        #expect(viewModel.selectedStyles.isEmpty)
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

        #expect(viewModel.selectedCategory == "전체")
        #expect(viewModel.isSchedulePickerPresented == false)
        #expect(viewModel.reservationSummaryText == "2/20 14:00-16:00")
    }

    @Test
    func applyScheduleSelectionAndActivateCategory_스타일선택상태면_스타일카테고리를유지한다() {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let start = makeTime(hour: 14, minute: 0)
        let end = makeTime(hour: 16, minute: 0)
        let viewModel = FeedViewModel(
            selectedCategory: "전체",
            selectedStyles: [.natural],
            isSchedulePickerPresented: true,
            selectedReservationDate: option,
            selectedStartTime: start,
            selectedEndTime: end,
            reservationDateOptions: [option]
        )

        viewModel.applyScheduleSelectionAndActivateCategory()

        #expect(viewModel.selectedCategory == viewModel.styleCategoryName)
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

    @Test
    func loadInitialFeed_성공하면아이템갱신된다() async {
        let item = makeFeedListItem(id: UUID(), likeCount: 77)
        let cityID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [item], nextCursor: nil))
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )
        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].likeCount == 77)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadInitialFeed_예약필터활성시_all카테고리와예약파라미터를전달한다() async {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let cityID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [], nextCursor: nil))
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )
        let viewModel = FeedViewModel(
            selectedCategory: "전체",
            selectedReservationDate: option,
            selectedStartTime: makeTime(hour: 14, minute: 0),
            selectedEndTime: makeTime(hour: 16, minute: 0),
            reservationDateOptions: [option],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeed(force: true)

        guard let request = service.fetchRequests.first else {
            Issue.record("피드 요청 기록이 없습니다.")
            return
        }

        #expect(request.category == .all)
        #expect(request.reservationDate != nil)
        #expect(request.startTime != nil)
        #expect(request.endTime != nil)
    }

    @Test
    func loadInitialFeed_예약필터비활성시_예약파라미터를전달하지않는다() async {
        let cityID = UUID(uuidString: "22333333-2222-4222-8222-222222222222")!
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [], nextCursor: nil))
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )
        let viewModel = FeedViewModel(
            selectedCategory: "전체",
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeed(force: true)

        guard let request = service.fetchRequests.first else {
            Issue.record("피드 요청 기록이 없습니다.")
            return
        }

        #expect(request.reservationDate == nil)
        #expect(request.startTime == nil)
        #expect(request.endTime == nil)
    }

    @Test
    func loadInitialFeed_예약필터활성시_응답아이템을그대로유지한다() async {
        let option = FeedViewModel.ReservationDateOption(date: makeDate(year: 2026, month: 2, day: 20))
        let reservableItem = makeFeedListItem(id: UUID(), likeCount: 10, isReservable: true)
        let notReservableItem = makeFeedListItem(id: UUID(), likeCount: 20, isReservable: false)
        let cityID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [notReservableItem, reservableItem], nextCursor: nil))
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )
        let viewModel = FeedViewModel(
            selectedCategory: "전체",
            selectedReservationDate: option,
            selectedStartTime: makeTime(hour: 14, minute: 0),
            selectedEndTime: makeTime(hour: 16, minute: 0),
            reservationDateOptions: [option],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.count == 2)
        #expect(viewModel.items.map(\.id).contains(notReservableItem.id))
        #expect(viewModel.items.map(\.id).contains(reservableItem.id))
    }

    @Test
    func loadInitialFeed_실패하면에러메시지를노출한다() async {
        let cityID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let service = MockFeedService(
            listResults: [
                .failure(FeedMockServiceError.forcedFailure)
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )
        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    @Test
    func loadInitialFeed_실패해도기존아이템은유지된다() async {
        let cityID = UUID(uuidString: "44444444-4444-4444-9444-444444444444")!
        let existingItem = FeedItem(
            id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!,
            imageName: "natural",
            likeCount: 3,
            isReservable: true
        )
        let service = MockFeedService(
            listResults: [
                .failure(FeedMockServiceError.forcedFailure)
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )
        let viewModel = FeedViewModel(
            items: [existingItem],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].id == existingItem.id)
        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    @Test
    func loadMoreIfNeeded_커서가있으면추가로드한다() async {
        let first = makeFeedListItem(id: UUID(), likeCount: 10)
        let second = makeFeedListItem(id: UUID(), likeCount: 20)
        let cityID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [first], nextCursor: "cursor-1")),
                .success(FeedListResponse(items: [second], nextCursor: nil))
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )
        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )
        await viewModel.loadInitialFeed(force: true)

        guard let targetID = viewModel.items.last?.id else {
            Issue.record("첫 페이지 아이템이 비어 있습니다.")
            return
        }

        await viewModel.loadMoreIfNeeded(currentItemID: targetID)

        #expect(viewModel.items.count == 2)
        #expect(viewModel.items[1].likeCount == 20)
    }

    @Test
    func 초기지역선택_수동저장값이_자동선택보다우선한다() async {
        let cityID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let districtID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let city = RegionsListCityResponse(
            id: cityID,
            name: "서울",
            parentID: nil,
            level: 1,
            districts: [
                RegionsListDistrictResponse(
                    id: districtID,
                    name: "강남구",
                    parentID: cityID,
                    level: 2
                )
            ]
        )

        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(RegionsListResponse(cities: [city]))

        let preferenceStore = FeedRegionPreferenceStoreStub(initialPreference: .region(districtID))
        let autoSelector = FeedRegionAutoSelector(
            regionProvider: RegionProviderStub(result: .resolved(ShopRegion(sido: "부산", sigungu: "해운대구")))
        )

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: preferenceStore,
            regionAutoSelector: autoSelector
        )

        await viewModel.loadInitialFeedIfNeeded()

        #expect(viewModel.selectedCity?.id == cityID)
        #expect(viewModel.selectedDistrict == nil)
        #expect(viewModel.selectedRegionID == cityID)
        #expect(preferenceStore.storedPreference == .region(cityID))
    }

    @Test
    func 초기지역선택_위치성공시_city자동선택되고_강제선택해제된다() async {
        let cityID = UUID(uuidString: "10101010-1010-4010-8010-101010101010")!
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: nil),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .resolved(ShopRegion(sido: "서울", sigungu: "강남구")))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()

        #expect(viewModel.selectedCity?.id == cityID)
        #expect(viewModel.isRegionSelectionMandatory == false)
    }

    @Test
    func 초기지역선택_위치실패시_전체지역으로유지된다() async {
        let cityID = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )

        let autoSelector = FeedRegionAutoSelector(
            regionProvider: RegionProviderStub(result: .unavailable(.denied))
        )
        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: nil),
            regionAutoSelector: autoSelector
        )

        await viewModel.loadInitialFeedIfNeeded()

        #expect(viewModel.selectedRegionID == nil)
        #expect(viewModel.regionHeaderText == "지역 선택")
        #expect(viewModel.isRegionSelectionMandatory == true)
        #expect(viewModel.isRegionPickerPresented == true)
    }

    @Test
    func 지역변경시_fetchFeedList_인자에_regionID가반영된다() async {
        let cityID = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [], nextCursor: nil)),
                .success(FeedListResponse(items: [], nextCursor: nil))
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: nil),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()
        #expect(service.fetchRegionIDs.isEmpty)

        guard let city = viewModel.cities.first else {
            Issue.record("city 데이터가 없습니다.")
            return
        }

        viewModel.selectCity(city)
        viewModel.applyRegionSelection()
        await waitUntil { service.fetchRegionIDs.count >= 1 }

        #expect(service.fetchRegionIDs.first == cityID)
    }

    @Test
    func 시선택시_구목록은_해당시에한정된다() async {
        let seoulID = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!
        let busanID = UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!
        let seoulDistrictID = UUID(uuidString: "11111111-aaaa-4aaa-8aaa-111111111111")!
        let busanDistrictID = UUID(uuidString: "22222222-bbbb-4bbb-8bbb-222222222222")!

        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: seoulID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: [
                            RegionsListDistrictResponse(
                                id: seoulDistrictID,
                                name: "강남구",
                                parentID: seoulID,
                                level: 2
                            )
                        ]
                    ),
                    RegionsListCityResponse(
                        id: busanID,
                        name: "부산",
                        parentID: nil,
                        level: 1,
                        districts: [
                            RegionsListDistrictResponse(
                                id: busanDistrictID,
                                name: "해운대구",
                                parentID: busanID,
                                level: 2
                            )
                        ]
                    )
                ]
            )
        )

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: nil),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )
        await viewModel.loadInitialFeedIfNeeded()

        guard let seoul = viewModel.cities.first(where: { $0.id == seoulID }) else {
            Issue.record("서울 city 데이터가 없습니다.")
            return
        }
        viewModel.selectCity(seoul)

        #expect(viewModel.selectedDistricts.map(\.id) == [seoulDistrictID])
    }

    @Test
    func 퀵메뉴_최근동네없으면_현재city만노출된다() async {
        let cityID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let districtID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: [
                            RegionsListDistrictResponse(
                                id: districtID,
                                name: "강남구",
                                parentID: cityID,
                                level: 2
                            )
                        ]
                    )
                ]
            )
        )

        let recentStore = FeedRecentNeighborhoodStoreStub(initialIDs: [])
        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(districtID)),
            recentNeighborhoodStore: recentStore,
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()

        #expect(viewModel.quickNeighborhoodEntries.count == 1)
        #expect(viewModel.quickNeighborhoodEntries[0].kind == .current)
        #expect(viewModel.quickNeighborhoodEntries[0].title == "서울")
    }

    @Test
    func 퀵메뉴_다른동네선택시_recent가_앞으로갱신된다() async {
        let seoulID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let busanID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        let gangnamID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let haeundaeID = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!

        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [], nextCursor: nil)),
                .success(FeedListResponse(items: [], nextCursor: nil)),
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: seoulID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: [
                            RegionsListDistrictResponse(
                                id: gangnamID,
                                name: "강남구",
                                parentID: seoulID,
                                level: 2
                            )
                        ]
                    ),
                    RegionsListCityResponse(
                        id: busanID,
                        name: "부산",
                        parentID: nil,
                        level: 1,
                        districts: [
                            RegionsListDistrictResponse(
                                id: haeundaeID,
                                name: "해운대구",
                                parentID: busanID,
                                level: 2
                            )
                        ]
                    ),
                ]
            )
        )

        let recentStore = FeedRecentNeighborhoodStoreStub(initialIDs: [haeundaeID, gangnamID])
        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(gangnamID)),
            recentNeighborhoodStore: recentStore,
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()
        guard let otherEntry = viewModel.quickNeighborhoodEntries.first(where: {
            if case let .region(regionID) = $0.kind {
                return regionID == busanID
            }
            return false
        }) else {
            Issue.record("다른 동네 엔트리가 없습니다.")
            return
        }

        viewModel.selectQuickNeighborhood(otherEntry)
        await waitUntil { service.fetchRegionIDs.count >= 2 }

        #expect(viewModel.selectedRegionID == busanID)
        #expect(recentStore.storedIDs == [busanID, seoulID])
        #expect(service.fetchRegionIDs.dropFirst().first == busanID)
    }

    @Test
    func 퀵메뉴_현재동네재선택시_재조회하지않는다() async {
        let cityID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            recentNeighborhoodStore: FeedRecentNeighborhoodStoreStub(initialIDs: [cityID]),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()
        guard let currentEntry = viewModel.quickNeighborhoodEntries.first else {
            Issue.record("현재 동네 엔트리가 없습니다.")
            return
        }

        viewModel.selectQuickNeighborhood(currentEntry)
        await Task.yield()

        #expect(service.fetchRegionIDs.count == 1)
    }

    @Test
    func 퀵메뉴_전체지역엔트리는_노출되지않는다() async {
        let cityID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(cityID)),
            recentNeighborhoodStore: FeedRecentNeighborhoodStoreStub(initialIDs: [cityID]),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()

        let hasAllEntry = viewModel.quickNeighborhoodEntries.contains { entry in
            if case .region = entry.kind {
                return false
            }
            return entry.title == "전체 지역"
        }
        #expect(hasAllEntry == false)
    }

    @Test
    func 지역목록실패시_picker상태가_failed로전환된다() async {
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .failure(FeedMockServiceError.forcedFailure)

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: nil),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()

        #expect(viewModel.regionPickerState == .failed)
        #expect(viewModel.isRegionSelectionMandatory == true)
        #expect(viewModel.isRegionPickerPresented == true)
    }

    @Test
    func 지역목록_빈응답이면_picker상태가_empty로전환된다() async {
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .success(RegionsListResponse(cities: []))

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: nil),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()

        #expect(viewModel.regionPickerState == .empty)
        #expect(viewModel.isRegionSelectionMandatory == true)
    }

    @Test
    func retryRegionPickerLoading_성공시_선택이해결되고_state가_loaded가된다() async {
        let cityID = UUID(uuidString: "12121212-1212-4212-8212-121212121212")!
        let service = MockFeedService(
            listResults: [.success(FeedListResponse(items: [], nextCursor: nil))]
        )
        service.regionsResult = .failure(FeedMockServiceError.forcedFailure)

        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: nil),
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .resolved(ShopRegion(sido: "서울", sigungu: nil)))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()
        #expect(viewModel.regionPickerState == .failed)

        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: cityID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    )
                ]
            )
        )

        viewModel.retryRegionPickerLoading()
        await waitUntil { viewModel.regionPickerState == .loaded }

        #expect(viewModel.selectedCity?.id == cityID)
        #expect(viewModel.isRegionSelectionMandatory == false)
    }

    @Test
    func 내동네설정진입시_메뉴닫히고전체화면선택이열린다() {
        let viewModel = FeedViewModel()

        viewModel.toggleNeighborhoodMenu()
        #expect(viewModel.isNeighborhoodMenuPresented == true)

        viewModel.presentNeighborhoodSettings()

        #expect(viewModel.isNeighborhoodMenuPresented == false)
        #expect(viewModel.isRegionPickerPresented == true)
    }

    @Test
    func 설정화면에서지역변경후_퀵메뉴엔트리가갱신된다() async {
        let seoulID = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
        let busanID = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!

        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [], nextCursor: nil)),
                .success(FeedListResponse(items: [], nextCursor: nil)),
            ]
        )
        service.regionsResult = .success(
            RegionsListResponse(
                cities: [
                    RegionsListCityResponse(
                        id: seoulID,
                        name: "서울",
                        parentID: nil,
                        level: 1,
                        districts: []
                    ),
                    RegionsListCityResponse(
                        id: busanID,
                        name: "부산",
                        parentID: nil,
                        level: 1,
                        districts: []
                    ),
                ]
            )
        )

        let recentStore = FeedRecentNeighborhoodStoreStub(initialIDs: [seoulID])
        let viewModel = FeedViewModel(
            items: [],
            service: service,
            regionPreferenceStore: FeedRegionPreferenceStoreStub(initialPreference: .region(seoulID)),
            recentNeighborhoodStore: recentStore,
            regionAutoSelector: FeedRegionAutoSelector(
                regionProvider: RegionProviderStub(result: .unavailable(.locationUnavailable))
            )
        )

        await viewModel.loadInitialFeedIfNeeded()
        guard let busan = viewModel.cities.first(where: { $0.id == busanID }) else {
            Issue.record("부산 city 데이터가 없습니다.")
            return
        }

        viewModel.selectCity(busan)
        viewModel.applyRegionSelection()
        await waitUntil { service.fetchRegionIDs.count >= 2 }

        #expect(viewModel.quickNeighborhoodEntries.first?.title == "부산")
        #expect(recentStore.storedIDs == [busanID, seoulID])
    }

    private func makeFeedListItem(id: UUID, likeCount: Int, isReservable: Bool = true) -> FeedListItemResponse {
        FeedListItemResponse(
            id: id,
            thumbnailURL: "https://example.com/thumb.jpg",
            likeCount: likeCount,
            isReservable: isReservable,
            isLiked: false,
            styleTags: ["프렌치"],
            createdAt: Date()
        )
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

    private func waitUntil(
        timeoutSeconds: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
    }
}

private enum FeedMockServiceError: Error {
    case forcedFailure
    case missingLikeResult
}

@MainActor
private final class MockFeedService: FeedServicing {
    struct FeedListRequest {
        let styles: [String]
        let category: FeedListCategory
        let regionID: UUID?
        let reservationDate: String?
        let startTime: String?
        let endTime: String?
    }

    var listResults: [Result<FeedListResponse, Error>]
    var likeResults: [Result<FeedLikeResponse, Error>]
    var regionsResult: Result<RegionsListResponse, Error> = .success(RegionsListResponse(cities: []))
    var fetchRegionIDs: [UUID?] = []
    var fetchRequests: [FeedListRequest] = []

    init(
        listResults: [Result<FeedListResponse, Error>],
        likeResults: [Result<FeedLikeResponse, Error>] = []
    ) {
        self.listResults = listResults
        self.likeResults = likeResults
    }

    func fetchFeedList(
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        regionID: UUID?,
        includeDescendants: Bool,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> FeedListResponse {
        fetchRequests.append(
            FeedListRequest(
                styles: styles,
                category: category,
                regionID: regionID,
                reservationDate: reservationDate,
                startTime: startTime,
                endTime: endTime
            )
        )
        fetchRegionIDs.append(regionID)
        guard !listResults.isEmpty else {
            throw FeedMockServiceError.forcedFailure
        }
        let result = listResults.removeFirst()
        return try result.get()
    }

    func fetchFeedList(
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> FeedListResponse {
        try await fetchFeedList(
            limit: limit,
            cursor: cursor,
            styles: styles,
            category: category,
            regionID: nil,
            includeDescendants: true,
            reservationDate: reservationDate,
            startTime: startTime,
            endTime: endTime
        )
    }

    func fetchFeedDetail(postId: UUID) async throws -> FeedDetailResponse {
        FeedDetailResponse(
            post: FeedDetailPostResponse(
                id: postId,
                title: "테스트",
                thumbnailURL: "https://example.com/thumb.jpg",
                shopId: nil,
                likeCount: 10,
                isReservable: true,
                isLiked: false,
                styleTags: [],
                studioName: "스튜디오",
                locationText: "강남",
                distanceKM: 1.2,
                originalPrice: 50000,
                discountedPrice: 40000,
                durationMin: 60,
                description: "desc",
                reviewCount: 0,
                ratingAvg: 5.0,
                createdAt: Date()
            ),
            galleryImageURLs: [],
            recentReviews: []
        )
    }

    func setFeedLike(postId: UUID, isLiked: Bool) async throws -> FeedLikeResponse {
        guard !likeResults.isEmpty else {
            throw FeedMockServiceError.missingLikeResult
        }
        let result = likeResults.removeFirst()
        return try result.get()
    }

    func fetchRegions() async throws -> RegionsListResponse {
        try regionsResult.get()
    }
}

@MainActor
private final class FeedRegionPreferenceStoreStub: FeedRegionPreferenceStoring {
    private(set) var storedPreference: FeedRegionPreference?

    init(initialPreference: FeedRegionPreference?) {
        self.storedPreference = initialPreference
    }

    func load() -> FeedRegionPreference? {
        storedPreference
    }

    func save(_ preference: FeedRegionPreference) {
        storedPreference = preference
    }

    func clear() {
        storedPreference = nil
    }
}

@MainActor
private final class FeedRecentNeighborhoodStoreStub: FeedRecentNeighborhoodStoring {
    private(set) var storedIDs: [UUID]

    init(initialIDs: [UUID]) {
        storedIDs = Array(initialIDs.prefix(2))
    }

    func load() -> [UUID] {
        storedIDs
    }

    func save(_ ids: [UUID]) {
        var unique: [UUID] = []
        var seen: Set<UUID> = []
        for id in ids where seen.insert(id).inserted {
            unique.append(id)
            if unique.count == 2 {
                break
            }
        }
        storedIDs = unique
    }

    func clear() {
        storedIDs = []
    }
}

@MainActor
private final class RegionProviderStub: CurrentRegionProviding {
    let result: ShopRegionResolution

    init(result: ShopRegionResolution) {
        self.result = result
    }

    func fetchCurrentRegion() async -> ShopRegionResolution {
        result
    }
}

#endif
