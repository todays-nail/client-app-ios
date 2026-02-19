#if false
import Foundation
import Testing
@testable import NailClient

@MainActor
struct FeedReservationAvailabilityTests {
    @Test
    func parseMinutes_HHmm과HHmmss를파싱한다() {
        #expect(FeedReservationAvailability.parseMinutes(from: "09:30") == 570)
        #expect(FeedReservationAvailability.parseMinutes(from: "09:30:00") == 570)
        #expect(FeedReservationAvailability.parseMinutes(from: "") == nil)
        #expect(FeedReservationAvailability.parseMinutes(from: "invalid") == nil)
    }

    @Test
    func dateKey_UTC기준으로생성한다() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 2,
            day: 20,
            hour: 0,
            minute: 30
        )
        let date = components.date ?? Date(timeIntervalSince1970: 0)

        #expect(FeedReservationAvailability.dateKey(for: date) == "2026-02-19")
    }

    @Test
    func makeTimeGrid_영업시간기준_30분단위로생성된다() {
        let date = makeDate(year: 2026, month: 2, day: 20)
        let grid = FeedReservationAvailability.makeTimeGrid(
            for: date,
            openTime: "10:00",
            closeTime: "11:30",
            fallbackSlots: []
        )

        #expect(grid.count == 4)
        #expect(FeedReservationAvailability.minuteKey(from: grid[0]) == 600)
        #expect(FeedReservationAvailability.minuteKey(from: grid[3]) == 690)
    }

    @Test
    func makeTimeGrid_영업시간없으면슬롯기반으로정렬반환한다() {
        let shopID = UUID()
        let date = makeDate(year: 2026, month: 2, day: 20)
        let dayStart = Calendar.current.startOfDay(for: date)

        let slotA = ReservationSlotResponse(
            id: UUID(),
            shopId: shopID,
            startAt: Calendar.current.date(byAdding: .minute, value: 630, to: dayStart) ?? dayStart,
            durationMin: 60,
            capacity: 1,
            status: "AVAILABLE"
        )
        let slotB = ReservationSlotResponse(
            id: UUID(),
            shopId: shopID,
            startAt: Calendar.current.date(byAdding: .minute, value: 600, to: dayStart) ?? dayStart,
            durationMin: 60,
            capacity: 1,
            status: "AVAILABLE"
        )
        let slotC = ReservationSlotResponse(
            id: UUID(),
            shopId: shopID,
            startAt: slotB.startAt,
            durationMin: 60,
            capacity: 1,
            status: "AVAILABLE"
        )

        let grid = FeedReservationAvailability.makeTimeGrid(
            for: date,
            openTime: nil,
            closeTime: nil,
            fallbackSlots: [slotA, slotB, slotC]
        )

        #expect(grid.count == 2)
        #expect(FeedReservationAvailability.minuteKey(from: grid[0]) == 600)
        #expect(FeedReservationAvailability.minuteKey(from: grid[1]) == 630)
    }

    @Test
    func isClosed_휴무요일문자열을정규화해판정한다() {
        let closed = FeedReservationAvailability.makeClosedWeekdaySet(["월요일", "fri"])
        let monday = firstDate(matchingWeekday: 2)
        let friday = firstDate(matchingWeekday: 6)
        let tuesday = firstDate(matchingWeekday: 3)

        #expect(FeedReservationAvailability.isClosed(date: monday, closedWeekdays: closed) == true)
        #expect(FeedReservationAvailability.isClosed(date: friday, closedWeekdays: closed) == true)
        #expect(FeedReservationAvailability.isClosed(date: tuesday, closedWeekdays: closed) == false)
    }

    @Test
    func earliestSlot_여러날짜중가장빠른시작슬롯을반환한다() {
        let slotA = makeSlot(year: 2026, month: 2, day: 20, minute: 600)
        let slotB = makeSlot(year: 2026, month: 2, day: 18, minute: 660)
        let slotC = makeSlot(year: 2026, month: 2, day: 18, minute: 540)

        let grouped = FeedReservationAvailability.groupedSlotsByDateKey([slotA, slotB, slotC])
        let earliest = FeedReservationAvailability.earliestSlot(in: grouped)

        #expect(earliest?.id == slotC.id)
    }

    @Test
    func slots_선택날짜슬롯을오름차순으로반환한다() {
        let slotA = makeSlot(year: 2026, month: 2, day: 21, minute: 660)
        let slotB = makeSlot(year: 2026, month: 2, day: 21, minute: 540)

        let grouped = FeedReservationAvailability.groupedSlotsByDateKey([slotA, slotB])
        let selectedDate = slotA.startAt

        let slots = FeedReservationAvailability.slots(for: selectedDate, in: grouped)
        #expect(slots.map(\.id) == [slotB.id, slotA.id])
    }

    @Test
    func firstSlot_날짜변경시해당날짜첫슬롯을반환한다() {
        let slotA = makeSlot(year: 2026, month: 2, day: 22, minute: 600)
        let slotB = makeSlot(year: 2026, month: 2, day: 22, minute: 690)
        let grouped = FeedReservationAvailability.groupedSlotsByDateKey([slotB, slotA])

        let selectedDate = slotA.startAt
        let firstSlot = FeedReservationAvailability.firstSlot(for: selectedDate, in: grouped)

        #expect(firstSlot?.id == slotA.id)
    }

    @Test
    func earliestSlot_빈슬롯이면_nil을반환한다() {
        let earliest = FeedReservationAvailability.earliestSlot(in: [:])
        #expect(earliest == nil)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
            ?? Date(timeIntervalSince1970: 0)
    }

    private func firstDate(matchingWeekday weekday: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        var date = makeDate(year: 2026, month: 2, day: 1)
        for _ in 0..<14 {
            if calendar.component(.weekday, from: date) == weekday {
                return date
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    private func makeSlot(year: Int, month: Int, day: Int, minute: Int) -> ReservationSlotResponse {
        let shopID = UUID()
        let date = makeDate(year: year, month: month, day: day)
        let dayStart = Calendar.current.startOfDay(for: date)

        return ReservationSlotResponse(
            id: UUID(),
            shopId: shopID,
            startAt: Calendar.current.date(byAdding: .minute, value: minute, to: dayStart) ?? dayStart,
            durationMin: 60,
            capacity: 1,
            status: "AVAILABLE"
        )
    }
}

#endif
