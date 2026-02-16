//
//  ReservationMockData.swift
//  NailClient
//

import Foundation

enum ReservationMockData {
    static func upcoming(now: Date = Date(), calendar: Calendar = .current) -> [UpcomingReservation] {
        [
            UpcomingReservation(
                id: UUID(uuidString: "0D8AD67D-7F4B-4A40-9327-A7824CA30011") ?? UUID(),
                salonName: "네일바이오늘",
                address: "서울 강남구 테헤란로 123",
                artistName: "수진 실장",
                serviceName: "담당 디자이너",
                date: date(byAddingDays: 3, hour: 14, minute: 0, from: now, calendar: calendar),
                dDay: 3,
                isAIFitting: true,
                statusLabel: "예약 확정"
            ),
            UpcomingReservation(
                id: UUID(uuidString: "B55395D7-C1A3-4BB5-A7A9-43298DA7F911") ?? UUID(),
                salonName: "네일팩토리",
                address: "서울 강남구 선릉로 77",
                artistName: "민지 디자이너",
                serviceName: "이달의 아트",
                date: date(byAddingDays: 10, hour: 11, minute: 30, from: now, calendar: calendar),
                dDay: 10,
                isAIFitting: false,
                statusLabel: "예약 확정"
            )
        ]
    }

    static func past(now: Date = Date(), calendar: Calendar = .current) -> [PastReservation] {
        [
            PastReservation(
                id: UUID(uuidString: "D62627C3-F971-450C-B694-E94BFA311001") ?? UUID(),
                salonName: "블링블링 네일",
                visitedAt: date(byAddingDays: -37, hour: 18, minute: 30, from: now, calendar: calendar),
                thumbnailName: "french",
                tags: ["젤네일", "아트 추가"],
                reviewStatus: .writable
            ),
            PastReservation(
                id: UUID(uuidString: "A224D2E5-71F0-49FD-B67D-329B318B1002") ?? UUID(),
                salonName: "손끝의 예술",
                visitedAt: date(byAddingDays: -63, hour: 11, minute: 0, from: now, calendar: calendar),
                thumbnailName: "chic_modern",
                tags: ["기본 케어"],
                reviewStatus: .completed
            ),
            PastReservation(
                id: UUID(uuidString: "9A4A1374-BEA9-4AB4-8E6C-A7E6A9F91003") ?? UUID(),
                salonName: "네일 팩토리",
                visitedAt: date(byAddingDays: -79, hour: 19, minute: 0, from: now, calendar: calendar),
                thumbnailName: "natural",
                tags: ["이달의 아트"],
                reviewStatus: .writable
            ),
            PastReservation(
                id: UUID(uuidString: "89E7AE7D-8D74-40CD-B2B9-31A53B311004") ?? UUID(),
                salonName: "아뜰리에 네일",
                visitedAt: date(byAddingDays: -102, hour: 15, minute: 30, from: now, calendar: calendar),
                thumbnailName: "glitter_pearl",
                tags: ["글리터", "오버레이"],
                reviewStatus: .completed
            ),
            PastReservation(
                id: UUID(uuidString: "93D9D6B6-E0C3-4E57-A020-9592CF3E1005") ?? UUID(),
                salonName: "로즈 네일샵",
                visitedAt: date(byAddingDays: -126, hour: 16, minute: 0, from: now, calendar: calendar),
                thumbnailName: "lovely",
                tags: ["웨딩", "포인트"],
                reviewStatus: .writable
            ),
            PastReservation(
                id: UUID(uuidString: "2F239BAF-5B31-4679-A227-E6FB728E1006") ?? UUID(),
                salonName: "네일 바이 밤",
                visitedAt: date(byAddingDays: -158, hour: 13, minute: 30, from: now, calendar: calendar),
                thumbnailName: "hip",
                tags: ["시럽"],
                reviewStatus: .completed
            )
        ]
    }

    private static func date(
        byAddingDays days: Int,
        hour: Int,
        minute: Int,
        from base: Date,
        calendar: Calendar
    ) -> Date {
        let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
        var components = calendar.dateComponents([.year, .month, .day], from: shifted)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? shifted
    }
}
