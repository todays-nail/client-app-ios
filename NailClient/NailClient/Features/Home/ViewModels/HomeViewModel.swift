//
//  HomeViewModel.swift
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
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
    @Published private(set) var items: [HomeFeedItem]
    @Published private(set) var selectedStyles: [StyleOption]
    @Published var isStylePickerPresented: Bool
    @Published var showMaxStyleAlert: Bool
    @Published var isSchedulePickerPresented: Bool
    @Published private(set) var selectedReservationDate: ReservationDateOption?
    @Published private(set) var selectedStartTime: Date?
    @Published private(set) var selectedEndTime: Date?
    @Published var showInvalidScheduleAlert: Bool

    let maxStyleSelectionCount: Int
    let styleCategoryName: String
    let scheduleCategoryName: String
    let categories: [String]
    let reservationDateOptions: [ReservationDateOption]
    let reservationTimeSlots: [Date]

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
    
    var filteredItems: [HomeFeedItem] {
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
        items: [HomeFeedItem]? = nil,
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
        reservationTimeSlots: [Date]? = nil
    ) {
        let resolvedCategories = categories ?? HomeMockData.categories
        self.categories = resolvedCategories
        self.items = items ?? HomeMockData.feedItems
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
    }

    func selectCategory(_ category: String) {
        guard categories.contains(category) else { return }
        selectedCategory = category
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
            return
        }

        guard selectedStyles.count < maxStyleSelectionCount else {
            showMaxStyleAlert = true
            return
        }

        selectedStyles.append(style)
    }

    func removeStyle(_ style: StyleOption) {
        selectedStyles.removeAll(where: { $0 == style })
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
    }

    func clearScheduleSelection() {
        selectedReservationDate = nil
        selectedStartTime = nil
        selectedEndTime = nil
        showInvalidScheduleAlert = false
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

    func toggleLike(for itemID: HomeFeedItem.ID) {
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
}
