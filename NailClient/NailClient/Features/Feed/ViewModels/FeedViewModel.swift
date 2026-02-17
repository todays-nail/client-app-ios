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

    func fetchFeedDetail(postId: UUID) async throws -> FeedDetailResponse
}

extension AppViewModel: FeedServicing {}

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

    @Published private(set) var selectedCategory: String
    @Published private(set) var items: [FeedItem]
    @Published private(set) var selectedStyles: [StyleOption]
    @Published var isStylePickerPresented: Bool
    @Published var showMaxStyleAlert: Bool
    @Published var isSchedulePickerPresented: Bool
    @Published private(set) var selectedReservationDate: ReservationDateOption?
    @Published private(set) var selectedStartTime: Date?
    @Published private(set) var selectedEndTime: Date?
    @Published var showInvalidScheduleAlert: Bool
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    let maxStyleSelectionCount: Int
    let styleCategoryName: String
    let scheduleCategoryName: String
    let categories: [String]
    let reservationDateOptions: [ReservationDateOption]
    let reservationTimeSlots: [Date]

    private weak var service: (any FeedServicing)?
    private var nextCursor: String?
    private var didLoadOnce: Bool = false
    private let pageSize: Int

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

    var filteredItems: [FeedItem] {
        guard service == nil else {
            return items
        }

        if selectedCategory == "전체" {
            return items
        }
        if selectedCategory == styleCategoryName {
            return items.filter { $0.isReservable == false }
        }
        if selectedCategory == scheduleCategoryName {
            return items.filter(\.isReservable)
        }
        return items
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
        pageSize: Int = 20
    ) {
        let resolvedCategories = categories ?? FeedMockData.categories
        self.categories = resolvedCategories
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
        self.selectedCategory = selectedCategory ?? resolvedCategories.first ?? "전체"
        self.service = service
        self.pageSize = pageSize

        if service == nil, self.items.isEmpty {
            self.items = FeedMockData.feedItems
        }
    }

    func bind(service: any FeedServicing) {
        self.service = service
    }

    func loadInitialFeedIfNeeded() async {
        guard !didLoadOnce else { return }
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

        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.fetchFeedList(
                limit: pageSize,
                cursor: nil,
                styles: selectedStyles.map(\.rawValue),
                category: currentFeedListCategory,
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
        guard selectedCategory != category else { return }
        selectedCategory = category
        triggerReloadIfNeeded()
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

        selectCategory(scheduleCategoryName)
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
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }

        if items[index].isLiked {
            items[index].isLiked = false
            items[index].likeCount = max(0, items[index].likeCount - 1)
        } else {
            items[index].isLiked = true
            items[index].likeCount += 1
        }
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

    private func mapFeedItems(_ responses: [FeedListItemResponse]) -> [FeedItem] {
        responses.map { row in
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
        if selectedCategory == scheduleCategoryName {
            return .reservable
        }
        if selectedCategory == styleCategoryName {
            return .style
        }
        return .all
    }

    private var reservationDateParam: String? {
        guard selectedCategory == scheduleCategoryName else { return nil }
        guard let selectedReservationDate else { return nil }
        return Self.requestDateFormatter.string(from: selectedReservationDate.date)
    }

    private var startTimeParam: String? {
        guard selectedCategory == scheduleCategoryName else { return nil }
        guard let selectedStartTime else { return nil }
        return Self.requestTimeFormatter.string(from: selectedStartTime)
    }

    private var endTimeParam: String? {
        guard selectedCategory == scheduleCategoryName else { return nil }
        guard let selectedEndTime else { return nil }
        return Self.requestTimeFormatter.string(from: selectedEndTime)
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
