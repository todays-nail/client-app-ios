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
                    shapeCategory: "스퀘어",
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
                    shapeCategory: "스퀘어",
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

    @Test
    func loadInitialFeed_성공하면아이템갱신된다() async {
        let item = makeFeedListItem(id: UUID(), likeCount: 77)
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [item], nextCursor: nil))
            ]
        )
        let viewModel = FeedViewModel(items: [], service: service)

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].likeCount == 77)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadInitialFeed_실패하면에러메시지를노출한다() async {
        let service = MockFeedService(
            listResults: [
                .failure(FeedMockServiceError.forcedFailure)
            ]
        )
        let viewModel = FeedViewModel(items: [], service: service)

        await viewModel.loadInitialFeed(force: true)

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    @Test
    func loadMoreIfNeeded_커서가있으면추가로드한다() async {
        let first = makeFeedListItem(id: UUID(), likeCount: 10)
        let second = makeFeedListItem(id: UUID(), likeCount: 20)
        let service = MockFeedService(
            listResults: [
                .success(FeedListResponse(items: [first], nextCursor: "cursor-1")),
                .success(FeedListResponse(items: [second], nextCursor: nil))
            ]
        )
        let viewModel = FeedViewModel(items: [], service: service)
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
        #expect(viewModel.selectedDistrict?.id == districtID)
        #expect(viewModel.selectedRegionID == districtID)
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
        #expect(viewModel.regionHeaderText == "전체 지역")
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
        #expect(service.fetchRegionIDs.first == nil)

        guard let city = viewModel.cities.first else {
            Issue.record("city 데이터가 없습니다.")
            return
        }

        viewModel.selectCity(city)
        viewModel.applyRegionSelection()
        await waitUntil { service.fetchRegionIDs.count >= 2 }

        #expect(service.fetchRegionIDs.dropFirst().first == cityID)
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

    private func makeFeedListItem(id: UUID, likeCount: Int) -> FeedListItemResponse {
        FeedListItemResponse(
            id: id,
            thumbnailURL: "https://example.com/thumb.jpg",
            likeCount: likeCount,
            shapeCategory: "스퀘어",
            isReservable: true,
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
    var listResults: [Result<FeedListResponse, Error>]
    var likeResults: [Result<FeedLikeResponse, Error>]
    var regionsResult: Result<RegionsListResponse, Error> = .success(RegionsListResponse(cities: []))
    var fetchRegionIDs: [UUID?] = []

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
                shapeCategory: "아몬드",
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
private final class RegionProviderStub: CurrentRegionProviding {
    let result: ShopRegionResolution

    init(result: ShopRegionResolution) {
        self.result = result
    }

    func fetchCurrentRegion() async -> ShopRegionResolution {
        result
    }
}
