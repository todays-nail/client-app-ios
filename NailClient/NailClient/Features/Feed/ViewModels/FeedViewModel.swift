//
//  FeedViewModel.swift
//

import Foundation
import Combine

@MainActor
protocol FeedServicing: AnyObject {
    func fetchFeedList(
        limit: Int,
        cursor: String?,
        styles: [String],
        category: FeedListCategory,
        reservationDate: String?,
        startTime: String?,
        endTime: String?
    ) async throws -> FeedListResponse
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
    ) async throws -> FeedListResponse
    func fetchRegions() async throws -> RegionsListResponse

    func fetchFeedDetail(postId: UUID) async throws -> FeedDetailResponse

    func setFeedLike(postId: UUID, isLiked: Bool) async throws -> FeedLikeResponse
}

extension AppViewModel: FeedServicing {}

extension FeedServicing {
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
        try await fetchFeedList(
            limit: limit,
            cursor: cursor,
            styles: styles,
            category: category,
            reservationDate: reservationDate,
            startTime: startTime,
            endTime: endTime
        )
    }

    func fetchRegions() async throws -> RegionsListResponse {
        RegionsListResponse(cities: [])
    }
}

@MainActor
final class FeedViewModel: ObservableObject {
    struct ReservationDateOption: Identifiable, Equatable {
        let date: Date

        var id: Date { date }

        init(date: Date, calendar: Calendar = .current) {
            self.date = calendar.startOfDay(for: date)
        }
    }

    enum StyleOption: String, CaseIterable, Identifiable {
        case officeMinimal = "오피스/미니멀"
        case natural = "청순/내추럴"
        case lovelyCute = "러블리/귀여움"
        case hipStreet = "힙/스트릿"
        case chicModern = "시크/모던"
        case kitschUnique = "키치/유니크"
        case glitterPearl = "글리터/펄"
        case french = "프렌치"
        case gradationOmbre = "그라데이션/옴브레"
        case wedding = "웨딩"
        case seasonHoliday = "시즌/홀리데이"
        case pointArt = "포인트아트"

        var id: String { rawValue }
        var displayName: String { rawValue }
    }

    struct QuickNeighborhoodEntry: Identifiable, Equatable {
        enum Kind: Equatable {
            case current
            case region(UUID)
            case all
        }

        let kind: Kind
        let title: String
        let isSelected: Bool

        var id: String {
            switch kind {
            case .current:
                return "current"
            case let .region(regionID):
                return regionID.uuidString.lowercased()
            case .all:
                return "all"
            }
        }
    }

    @Published private(set) var selectedCategory: String
    @Published private(set) var items: [FeedItem]
    @Published private(set) var cities: [FeedRegion] = []
    @Published private(set) var districtsByCityID: [UUID: [FeedRegion]] = [:]
    @Published private(set) var selectedCity: FeedRegion?
    @Published private(set) var selectedDistrict: FeedRegion?
    @Published private(set) var selectedStyles: [StyleOption]
    @Published var isStylePickerPresented: Bool
    @Published var isRegionPickerPresented: Bool = false
    @Published var isNeighborhoodMenuPresented: Bool = false
    @Published private(set) var quickNeighborhoodEntries: [QuickNeighborhoodEntry] = []
    @Published private(set) var isRegionLoading: Bool = false
    @Published var showMaxStyleAlert: Bool
    @Published var isSchedulePickerPresented: Bool
    @Published private(set) var selectedReservationDate: ReservationDateOption?
    @Published private(set) var selectedStartTime: Date?
    @Published private(set) var selectedEndTime: Date?
    @Published var showInvalidScheduleAlert: Bool
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published var errorMessage: String?
    @Published var likeErrorMessage: String?

    let maxStyleSelectionCount: Int
    let styleCategoryName: String
    let scheduleCategoryName: String
    let categories: [String]
    let reservationDateOptions: [ReservationDateOption]
    let reservationTimeSlots: [Date]

    private weak var service: (any FeedServicing)?
    private let allCategoryName: String
    private var nextCursor: String?
    private var didLoadOnce: Bool = false
    private var didResolveInitialRegion: Bool = false
    private var inFlightLikeItemIDs: Set<FeedItem.ID> = []
    private let pageSize: Int
    private let regionPreferenceStore: any FeedRegionPreferenceStoring
    private let recentNeighborhoodStore: any FeedRecentNeighborhoodStoring
    private let regionAutoSelector: FeedRegionAutoSelector

    var reservationSummaryText: String? {
        guard
            let selectedReservationDate,
            let selectedStartTime,
            let selectedEndTime
        else {
            return nil
        }

        let dateText = Self.summaryDateFormatter.string(from: selectedReservationDate.date)
        let startText = Self.summaryTimeFormatter.string(from: selectedStartTime)
        let endText = Self.summaryTimeFormatter.string(from: selectedEndTime)
        return "\(dateText) \(startText)-\(endText)"
    }

    var selectedRegionID: UUID? {
        selectedDistrict?.id ?? selectedCity?.id
    }

    var regionHeaderText: String {
        if let selectedCity, let selectedDistrict {
            return "\(selectedCity.name) \(selectedDistrict.name)"
        }
        if let selectedCity {
            return selectedCity.name
        }
        return "전체 지역"
    }

    var selectedDistricts: [FeedRegion] {
        guard let selectedCity else { return [] }
        return districtsByCityID[selectedCity.id] ?? []
    }

    var filteredItems: [FeedItem] {
        let baseItems: [FeedItem]
        if service == nil {
            if selectedCategory == allCategoryName {
                baseItems = items
            } else if selectedCategory == styleCategoryName {
                baseItems = items.filter { $0.isReservable == false }
            } else if selectedCategory == scheduleCategoryName {
                baseItems = items.filter(\.isReservable)
            } else {
                baseItems = items
            }
        } else {
            baseItems = items
        }

        guard shouldRestrictToReservableItems else {
            return baseItems
        }
        return baseItems.filter(\.isReservable)
    }

    init(
        selectedCategory: String? = nil,
        categories: [String]? = nil,
        items: [FeedItem]? = nil,
        selectedStyles: [StyleOption] = [],
        isStylePickerPresented: Bool = false,
        showMaxStyleAlert: Bool = false,
        isSchedulePickerPresented: Bool = false,
        selectedReservationDate: ReservationDateOption? = nil,
        selectedStartTime: Date? = nil,
        selectedEndTime: Date? = nil,
        showInvalidScheduleAlert: Bool = false,
        maxStyleSelectionCount: Int = 3,
        styleCategoryName: String = "스타일",
        scheduleCategoryName: String = "예약 가능 일정",
        reservationDateOptions: [ReservationDateOption]? = nil,
        reservationTimeSlots: [Date]? = nil,
        service: (any FeedServicing)? = nil,
        regionPreferenceStore: (any FeedRegionPreferenceStoring)? = nil,
        recentNeighborhoodStore: (any FeedRecentNeighborhoodStoring)? = nil,
        regionAutoSelector: FeedRegionAutoSelector? = nil,
        pageSize: Int = 20
    ) {
        let resolvedCategories = categories ?? FeedMockData.categories
        self.categories = resolvedCategories
        self.allCategoryName = resolvedCategories.first ?? "전체"
        self.items = items ?? []
        self.selectedStyles = selectedStyles
        self.isStylePickerPresented = isStylePickerPresented
        self.showMaxStyleAlert = showMaxStyleAlert
        self.isSchedulePickerPresented = isSchedulePickerPresented
        self.showInvalidScheduleAlert = showInvalidScheduleAlert
        self.maxStyleSelectionCount = maxStyleSelectionCount
        self.styleCategoryName = styleCategoryName
        self.scheduleCategoryName = scheduleCategoryName
        self.reservationDateOptions = reservationDateOptions ?? Self.makeReservationDateOptions()
        self.reservationTimeSlots = reservationTimeSlots ?? Self.makeReservationTimeSlots()
        self.selectedReservationDate = selectedReservationDate
        self.selectedStartTime = selectedStartTime
        self.selectedEndTime = selectedEndTime
        self.selectedCategory = selectedCategory ?? allCategoryName
        self.service = service
        self.regionPreferenceStore = regionPreferenceStore ?? FeedRegionPreferenceStore()
        self.recentNeighborhoodStore = recentNeighborhoodStore ?? FeedRecentNeighborhoodStore()
        self.regionAutoSelector = regionAutoSelector ?? FeedRegionAutoSelector()
        self.pageSize = pageSize

        if service == nil, self.items.isEmpty {
            self.items = FeedMockData.feedItems
        }

        refreshQuickNeighborhoodEntries()
    }

    func bind(service: any FeedServicing) {
        self.service = service
    }

    func loadInitialFeedIfNeeded() async {
        guard !didLoadOnce else { return }
        await resolveInitialRegionSelectionIfNeeded()
        await loadInitialFeed(force: false)
    }

    func loadInitialFeed(force: Bool = true) async {
        guard let service else {
            didLoadOnce = true
            if items.isEmpty {
                items = FeedMockData.feedItems
            }
            return
        }
        if isLoading { return }
        if didLoadOnce && !force { return }

        await resolveInitialRegionSelectionIfNeeded()

        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchFeedList(
                limit: pageSize,
                cursor: nil,
                styles: selectedStyles.map(\.rawValue),
                category: currentFeedListCategory,
                regionID: selectedRegionID,
                includeDescendants: true,
                reservationDate: reservationDateParam,
                startTime: startTimeParam,
                endTime: endTimeParam
            )

            items = mapFeedItems(response.items)
            nextCursor = response.nextCursor
            didLoadOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItemID: FeedItem.ID) async {
        guard !isLoading, !isLoadingMore else { return }
        guard let lastID = items.last?.id, lastID == currentItemID else { return }
        guard let nextCursor, !nextCursor.isEmpty else { return }
        guard let service else { return }

        isLoadingMore = true

        do {
            let response = try await service.fetchFeedList(
                limit: pageSize,
                cursor: nextCursor,
                styles: selectedStyles.map(\.rawValue),
                category: currentFeedListCategory,
                regionID: selectedRegionID,
                includeDescendants: true,
                reservationDate: reservationDateParam,
                startTime: startTimeParam,
                endTime: endTimeParam
            )

            let appended = mapFeedItems(response.items)
            var existing = Set(items.map(\.id))
            for item in appended where !existing.contains(item.id) {
                items.append(item)
                existing.insert(item.id)
            }

            if response.nextCursor == nextCursor {
                self.nextCursor = nil
            } else {
                self.nextCursor = response.nextCursor
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    func selectCategory(_ category: String) {
        guard categories.contains(category) else { return }

        var didResetStyles = false
        if category == allCategoryName, selectedStyles.isEmpty == false {
            selectedStyles.removeAll()
            didResetStyles = true
        }

        let didChangeCategory = selectedCategory != category
        if didChangeCategory {
            selectedCategory = category
        }

        if didChangeCategory || didResetStyles {
            triggerReloadIfNeeded()
        }
    }

    func handleStyleCategoryTap() {
        selectCategory(styleCategoryName)
        isStylePickerPresented = true
    }

    func handleScheduleCategoryTap() {
        prepareDefaultScheduleSelectionIfNeeded()
        showInvalidScheduleAlert = false
        isSchedulePickerPresented = true
    }

    func presentRegionPicker() {
        isNeighborhoodMenuPresented = false
        isRegionPickerPresented = true
        Task { [weak self] in
            await self?.loadRegionsIfNeeded()
        }
    }

    func toggleNeighborhoodMenu() {
        if isNeighborhoodMenuPresented {
            dismissNeighborhoodMenu()
            return
        }

        isNeighborhoodMenuPresented = true
        refreshQuickNeighborhoodEntries()
        Task { [weak self] in
            await self?.loadRegionsIfNeeded()
        }
    }

    func dismissNeighborhoodMenu() {
        isNeighborhoodMenuPresented = false
    }

    func selectQuickNeighborhood(_ entry: QuickNeighborhoodEntry) {
        switch entry.kind {
        case .current:
            dismissNeighborhoodMenu()
            return
        case .all:
            guard selectedRegionID != nil else {
                dismissNeighborhoodMenu()
                return
            }
            selectAllRegion()
            saveCurrentRegionPreference()
            refreshQuickNeighborhoodEntries()
            dismissNeighborhoodMenu()
            triggerReloadIfNeeded()
        case let .region(regionID):
            guard selectedRegionID != regionID else {
                dismissNeighborhoodMenu()
                return
            }
            guard applyRegionSelection(regionID: regionID) else {
                refreshQuickNeighborhoodEntries()
                dismissNeighborhoodMenu()
                return
            }

            saveCurrentRegionPreference()
            refreshQuickNeighborhoodEntries()
            dismissNeighborhoodMenu()
            triggerReloadIfNeeded()
        }
    }

    func presentNeighborhoodSettings() {
        dismissNeighborhoodMenu()
        presentRegionPicker()
    }

    func selectAllRegion() {
        selectedCity = nil
        selectedDistrict = nil
        refreshQuickNeighborhoodEntries()
    }

    func selectCity(_ city: FeedRegion) {
        selectedCity = city
        selectedDistrict = nil
        refreshQuickNeighborhoodEntries()
    }

    func selectDistrict(_ district: FeedRegion) {
        guard let selectedCity else { return }
        guard districtsByCityID[selectedCity.id]?.contains(district) == true else { return }
        selectedDistrict = district
        refreshQuickNeighborhoodEntries()
    }

    func applyRegionSelection() {
        saveCurrentRegionPreference()
        isRegionPickerPresented = false
        isNeighborhoodMenuPresented = false
        refreshQuickNeighborhoodEntries()
        triggerReloadIfNeeded()
    }

    func toggleStyle(_ style: StyleOption) {
        if let index = selectedStyles.firstIndex(of: style) {
            selectedStyles.remove(at: index)
            triggerReloadIfNeeded()
            return
        }

        guard selectedStyles.count < maxStyleSelectionCount else {
            showMaxStyleAlert = true
            return
        }

        selectedStyles.append(style)
        triggerReloadIfNeeded()
    }

    func removeStyle(_ style: StyleOption) {
        selectedStyles.removeAll(where: { $0 == style })
        triggerReloadIfNeeded()
    }

    func applyScheduleSelectionAndActivateCategory() {
        guard
            selectedReservationDate != nil,
            let selectedStartTime,
            let selectedEndTime,
            selectedEndTime > selectedStartTime
        else {
            showInvalidScheduleAlert = true
            return
        }

        selectedCategory = selectedStyles.isEmpty ? allCategoryName : styleCategoryName
        isSchedulePickerPresented = false
        showInvalidScheduleAlert = false
        triggerReloadIfNeeded()
    }

    func clearScheduleSelection() {
        selectedReservationDate = nil
        selectedStartTime = nil
        selectedEndTime = nil
        showInvalidScheduleAlert = false
        triggerReloadIfNeeded()
    }

    func selectReservationDate(_ option: ReservationDateOption) {
        selectedReservationDate = option
    }

    func updateStartTime(_ time: Date) {
        selectedStartTime = time
    }

    func updateEndTime(_ time: Date) {
        selectedEndTime = time
    }

    func toggleLike(for itemID: FeedItem.ID) {
        guard !inFlightLikeItemIDs.contains(itemID) else { return }
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        likeErrorMessage = nil
        let previousState = (isLiked: items[index].isLiked, likeCount: items[index].likeCount)

        if items[index].isLiked {
            items[index].isLiked = false
            items[index].likeCount = max(0, items[index].likeCount - 1)
        } else {
            items[index].isLiked = true
            items[index].likeCount += 1
        }

        guard let service else { return }

        let targetLiked = items[index].isLiked
        inFlightLikeItemIDs.insert(itemID)

        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlightLikeItemIDs.remove(itemID) }

            do {
                let response = try await service.setFeedLike(postId: itemID, isLiked: targetLiked)
                self.applyLikeState(for: itemID, isLiked: response.isLiked, likeCount: response.likeCount)
            } catch {
                self.applyLikeState(for: itemID, isLiked: previousState.isLiked, likeCount: previousState.likeCount)
                self.likeErrorMessage = "좋아요 반영에 실패했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    func applyLikeState(for itemID: FeedItem.ID, isLiked: Bool, likeCount: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].isLiked = isLiked
        items[index].likeCount = max(0, likeCount)
    }

    private func resolveInitialRegionSelectionIfNeeded() async {
        guard !didResolveInitialRegion else { return }
        didResolveInitialRegion = true

        guard service != nil else { return }
        await loadRegionsIfNeeded()

        if let preference = regionPreferenceStore.load() {
            applyPreference(preference)
            refreshQuickNeighborhoodEntries()
            return
        }

        guard !cities.isEmpty else {
            return
        }

        if let autoSelection = await regionAutoSelector.select(
            from: cities,
            districtsByCityID: districtsByCityID
        ) {
            selectedCity = autoSelection.city
            selectedDistrict = autoSelection.district
        }

        refreshQuickNeighborhoodEntries()
    }

    private func loadRegionsIfNeeded(force: Bool = false) async {
        if isRegionLoading { return }
        if !force && !cities.isEmpty { return }
        guard let service else { return }

        isRegionLoading = true
        defer { isRegionLoading = false }

        do {
            let response = try await service.fetchRegions()
            applyRegions(response)
        } catch {
            cities = []
            districtsByCityID = [:]
            refreshQuickNeighborhoodEntries()
        }
    }

    private func applyRegions(_ response: RegionsListResponse) {
        let mappedCities = response.cities.map { city in
            FeedRegion(
                id: city.id,
                name: city.name,
                parentID: city.parentID,
                level: city.level
            )
        }
        var mappedDistrictsByCityID: [UUID: [FeedRegion]] = [:]
        for city in response.cities {
            mappedDistrictsByCityID[city.id] = city.districts.map { district in
                FeedRegion(
                    id: district.id,
                    name: district.name,
                    parentID: district.parentID,
                    level: district.level
                )
            }
        }

        cities = mappedCities
        districtsByCityID = mappedDistrictsByCityID
        refreshQuickNeighborhoodEntries()
    }

    private func applyPreference(_ preference: FeedRegionPreference) {
        switch preference {
        case .all:
            selectedCity = nil
            selectedDistrict = nil
        case let .region(regionID):
            if applyRegionSelection(regionID: regionID) {
                return
            }
            selectedCity = nil
            selectedDistrict = nil
        }
    }

    @discardableResult
    private func applyRegionSelection(regionID: UUID) -> Bool {
        if let city = cities.first(where: { $0.id == regionID }) {
            selectedCity = city
            selectedDistrict = nil
            return true
        }

        for city in cities {
            guard let district = districtsByCityID[city.id]?.first(where: { $0.id == regionID }) else {
                continue
            }
            selectedCity = city
            selectedDistrict = district
            return true
        }
        return false
    }

    private func prepareDefaultScheduleSelectionIfNeeded() {
        if selectedReservationDate == nil {
            selectedReservationDate = reservationDateOptions.first
        }
        if selectedStartTime == nil {
            selectedStartTime = reservationTimeSlots.first
        }
        if selectedEndTime == nil {
            selectedEndTime = reservationTimeSlots.dropFirst().first ?? reservationTimeSlots.first
        }
    }

    private func triggerReloadIfNeeded() {
        guard service != nil else { return }
        Task { [weak self] in
            await self?.loadInitialFeed(force: true)
        }
    }

    private func saveCurrentRegionPreference() {
        if let selectedRegionID {
            regionPreferenceStore.save(.region(selectedRegionID))
            updateRecentNeighborhoods(with: selectedRegionID)
        } else {
            regionPreferenceStore.save(.all)
        }
    }

    private func updateRecentNeighborhoods(with regionID: UUID) {
        var ids = recentNeighborhoodStore.load()
        ids.removeAll(where: { $0 == regionID })
        ids.insert(regionID, at: 0)
        recentNeighborhoodStore.save(Array(ids.prefix(2)))
    }

    private func refreshQuickNeighborhoodEntries() {
        let regionsByID = regionLookupByID()
        let recentNeighborhoodIDs: [UUID]
        if regionsByID.isEmpty {
            recentNeighborhoodIDs = recentNeighborhoodStore.load()
        } else {
            let sanitized = recentNeighborhoodStore
                .load()
                .filter { regionsByID[$0] != nil }
            if sanitized != recentNeighborhoodStore.load() {
                recentNeighborhoodStore.save(sanitized)
            }
            recentNeighborhoodIDs = sanitized
        }

        var entries: [QuickNeighborhoodEntry] = [
            QuickNeighborhoodEntry(
                kind: .current,
                title: selectedDistrict?.name ?? selectedCity?.name ?? "전체 지역",
                isSelected: true
            ),
        ]

        if let currentRegionID = selectedRegionID,
           let otherRegionID = recentNeighborhoodIDs.first(where: { $0 != currentRegionID }),
           let otherRegion = regionsByID[otherRegionID] {
            entries.append(
                QuickNeighborhoodEntry(
                    kind: .region(otherRegionID),
                    title: otherRegion.name,
                    isSelected: false
                )
            )
        } else if selectedRegionID == nil,
                  let otherRegionID = recentNeighborhoodIDs.first,
                  let otherRegion = regionsByID[otherRegionID] {
            entries.append(
                QuickNeighborhoodEntry(
                    kind: .region(otherRegionID),
                    title: otherRegion.name,
                    isSelected: false
                )
            )
        }

        entries.append(
            QuickNeighborhoodEntry(
                kind: .all,
                title: "전체 지역",
                isSelected: selectedRegionID == nil
            )
        )

        quickNeighborhoodEntries = entries
    }

    private func regionLookupByID() -> [UUID: FeedRegion] {
        var regions: [UUID: FeedRegion] = [:]

        for city in cities {
            regions[city.id] = city
            for district in districtsByCityID[city.id] ?? [] {
                regions[district.id] = district
            }
        }

        return regions
    }

    private func mapFeedItems(_ responses: [FeedListItemResponse]) -> [FeedItem] {
        let filteredResponses = shouldRestrictToReservableItems
            ? responses.filter(\.isReservable)
            : responses

        return filteredResponses.map { row in
            FeedItem(
                id: row.id,
                thumbnailURL: URL(string: row.thumbnailURL),
                fallbackAssetName: Self.fallbackAssetName(id: row.id, styleTags: row.styleTags),
                likeCount: row.likeCount,
                shapeCategory: row.shapeCategory,
                isReservable: row.isReservable,
                isLiked: row.isLiked,
                styleTags: row.styleTags,
                createdAt: row.createdAt
            )
        }
    }

    private var currentFeedListCategory: FeedListCategory {
        if shouldRestrictToReservableItems {
            return .reservable
        }
        if selectedCategory == styleCategoryName {
            return .style
        }
        return .all
    }

    private var reservationDateParam: String? {
        guard hasActiveReservationFilter, let selectedReservationDate else { return nil }
        return Self.requestDateFormatter.string(from: selectedReservationDate.date)
    }

    private var startTimeParam: String? {
        guard hasActiveReservationFilter, let selectedStartTime else { return nil }
        return Self.requestTimeFormatter.string(from: selectedStartTime)
    }

    private var endTimeParam: String? {
        guard hasActiveReservationFilter, let selectedEndTime else { return nil }
        return Self.requestTimeFormatter.string(from: selectedEndTime)
    }

    private var hasActiveReservationFilter: Bool {
        selectedReservationDate != nil && selectedStartTime != nil && selectedEndTime != nil
    }

    private var shouldRestrictToReservableItems: Bool {
        hasActiveReservationFilter || selectedCategory == scheduleCategoryName
    }

    private static func fallbackAssetName(id: UUID, styleTags: [String]) -> String {
        let styleMap: [String: String] = [
            "오피스/미니멀": "office_minimal",
            "청순/내추럴": "natural",
            "러블리/귀여움": "lovely",
            "힙/스트릿": "hip",
            "시크/모던": "chic_modern",
            "키치/유니크": "kitsh_unique",
            "글리터/펄": "glitter_pearl",
            "프렌치": "french",
            "그라데이션/옴브레": "gradient_ombre",
            "웨딩": "wedding",
            "포인트아트": "point-art",
        ]

        for tag in styleTags {
            if let mapped = styleMap[tag] {
                return mapped
            }
        }

        let fallbackPool = FeedMockData.feedItems.map(\.imageName)
        guard !fallbackPool.isEmpty else { return "natural" }

        let seed = id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return fallbackPool[seed % fallbackPool.count]
    }

    private static func makeReservationDateOptions(now: Date = Date(), calendar: Calendar = .current) -> [ReservationDateOption] {
        let today = calendar.startOfDay(for: now)
        return (0...6).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return ReservationDateOption(date: date, calendar: calendar)
        }
    }

    private static func makeReservationTimeSlots(calendar: Calendar = .current) -> [Date] {
        guard let baseDate = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) else {
            return []
        }

        return stride(from: 10 * 60, through: 21 * 60, by: 30).compactMap { minuteOfDay in
            let hour = minuteOfDay / 60
            let minute = minuteOfDay % 60
            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: baseDate
            )
        }
    }

    private static let summaryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let summaryTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let requestDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let requestTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
