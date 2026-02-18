import Foundation

enum FeedReservationAvailability {
    nonisolated private static let utcTimeZone = TimeZone(secondsFromGMT: 0) ?? .current

    nonisolated static func dateKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: calendar.startOfDay(for: date))
    }

    nonisolated static func parseMinutes(from timeString: String?) -> Int? {
        guard let timeString else { return nil }
        let trimmed = timeString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        guard let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }

        return hour * 60 + minute
    }

    nonisolated static func makeTimeGrid(
        for date: Date,
        openTime: String?,
        closeTime: String?,
        fallbackSlots: [ReservationSlotResponse],
        stepMinutes: Int = 30,
        calendar: Calendar = .current
    ) -> [Date] {
        if let openMinutes = parseMinutes(from: openTime),
           let closeMinutes = parseMinutes(from: closeTime),
           closeMinutes > openMinutes {
            let dayStart = calendar.startOfDay(for: date)
            guard let start = calendar.date(byAdding: .minute, value: openMinutes, to: dayStart),
                  let end = calendar.date(byAdding: .minute, value: closeMinutes, to: dayStart) else {
                return []
            }

            var grid: [Date] = []
            var cursor = start
            while cursor <= end {
                grid.append(cursor)
                guard let next = calendar.date(byAdding: .minute, value: stepMinutes, to: cursor) else { break }
                cursor = next
            }
            return grid
        }

        return Array(Set(fallbackSlots.map(\.startAt))).sorted()
    }

    nonisolated static func minuteKey(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    nonisolated static func makeClosedWeekdaySet(_ weekdays: [String]) -> Set<String> {
        Set(weekdays.map(normalizeWeekdayToken))
    }

    nonisolated static func isClosed(date: Date, closedWeekdays: Set<String>, calendar: Calendar = .current) -> Bool {
        guard !closedWeekdays.isEmpty else { return false }
        let weekday = calendar.component(.weekday, from: date)
        let index = max(1, min(7, weekday)) - 1

        let englishShort = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][index]
        let englishLong = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"][index]
        let koreanShort = ["일", "월", "화", "수", "목", "금", "토"][index]
        let koreanLong = ["일요일", "월요일", "화요일", "수요일", "목요일", "금요일", "토요일"][index]

        let candidates = [
            normalizeWeekdayToken(englishShort),
            normalizeWeekdayToken(englishLong),
            normalizeWeekdayToken(koreanShort),
            normalizeWeekdayToken(koreanLong)
        ]

        return candidates.contains(where: { closedWeekdays.contains($0) })
    }

    nonisolated static func sortedSlots(_ slots: [ReservationSlotResponse]) -> [ReservationSlotResponse] {
        slots.sorted { $0.startAt < $1.startAt }
    }

    nonisolated static func groupedSlotsByDateKey(_ slots: [ReservationSlotResponse]) -> [String: [ReservationSlotResponse]] {
        Dictionary(grouping: slots, by: { dateKey(for: $0.startAt) })
            .mapValues(sortedSlots(_:))
    }

    nonisolated static func dateKeys(startingAt startDate: Date, days: Int, calendar: Calendar = .current) -> [String] {
        guard days > 0 else { return [] }
        let start = calendar.startOfDay(for: startDate)
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            return dateKey(for: date)
        }
    }

    nonisolated static func slots(for date: Date, in slotsByDateKey: [String: [ReservationSlotResponse]]) -> [ReservationSlotResponse] {
        let key = dateKey(for: date)
        return sortedSlots(slotsByDateKey[key] ?? [])
    }

    nonisolated static func firstSlot(for date: Date, in slotsByDateKey: [String: [ReservationSlotResponse]]) -> ReservationSlotResponse? {
        slots(for: date, in: slotsByDateKey).first
    }

    nonisolated static func earliestSlot(in slotsByDateKey: [String: [ReservationSlotResponse]]) -> ReservationSlotResponse? {
        sortedSlots(slotsByDateKey.values.flatMap { $0 }).first
    }

    nonisolated private static func normalizeWeekdayToken(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "요일", with: "")
            .uppercased()
    }
}
