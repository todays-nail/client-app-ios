import Foundation

enum ReservationAPIRepositoryError: Error {
    case invalidPaging
    case serviceUnavailable
    case nonSequentialPaging
}

@MainActor
final class ReservationAPIRepository: ReservationRepository {
    private weak var service: (any ReservationServicing)?
    private var pastCursorByPage: [Int: String?] = [0: nil]

    init(service: any ReservationServicing) {
        self.service = service
    }

    func bind(service: any ReservationServicing) {
        self.service = service
        resetPastCursor()
    }

    func fetchUpcoming() async throws -> [UpcomingReservation] {
        guard let service else {
            throw ReservationAPIRepositoryError.serviceUnavailable
        }

        let response = try await service.fetchReservationList(
            segment: .upcoming,
            limit: 20,
            cursor: nil
        )

        return mapUpcoming(from: response.items)
    }

    func fetchPast(page: Int, pageSize: Int) async throws -> ReservationPage<PastReservation> {
        guard page >= 0, pageSize > 0 else {
            throw ReservationAPIRepositoryError.invalidPaging
        }
        guard let service else {
            throw ReservationAPIRepositoryError.serviceUnavailable
        }

        if page == 0 {
            resetPastCursor()
        }

        try await ensurePastCursor(forPage: page, pageSize: pageSize, service: service)
        let cursor = pastCursorByPage[page] ?? nil

        let response = try await service.fetchReservationList(
            segment: .past,
            limit: pageSize,
            cursor: cursor
        )

        pastCursorByPage[page + 1] = response.nextCursor

        return ReservationPage(
            items: mapPast(from: response.items),
            hasNext: response.nextCursor != nil
        )
    }

    private func resetPastCursor() {
        pastCursorByPage = [0: nil]
    }

    private func ensurePastCursor(
        forPage targetPage: Int,
        pageSize: Int,
        service: any ReservationServicing
    ) async throws {
        if targetPage == 0 { return }
        if pastCursorByPage[targetPage] != nil { return }

        var page = 0
        while page < targetPage {
            guard pastCursorByPage[page] != nil else {
                throw ReservationAPIRepositoryError.nonSequentialPaging
            }
            if pastCursorByPage[page + 1] != nil {
                page += 1
                continue
            }

            let response = try await service.fetchReservationList(
                segment: .past,
                limit: pageSize,
                cursor: pastCursorByPage[page] ?? nil
            )
            pastCursorByPage[page + 1] = response.nextCursor

            if response.nextCursor == nil && page + 1 < targetPage {
                throw ReservationAPIRepositoryError.nonSequentialPaging
            }

            page += 1
        }
    }

    private func mapUpcoming(from rows: [ReservationItemResponse]) -> [UpcomingReservation] {
        rows.map { row in
            UpcomingReservation(
                id: row.id,
                salonName: row.shopName,
                address: row.shopAddress,
                artistName: "담당자 미정",
                serviceName: row.referenceTitle,
                date: row.slotStartAt,
                dDay: Self.makeDDay(target: row.slotStartAt),
                isAIFitting: row.aiGenerationId != nil || ((row.attachedImageURL?.isEmpty == false)),
                statusLabel: Self.mapStatusLabel(row.status)
            )
        }
    }

    private func mapPast(from rows: [ReservationItemResponse]) -> [PastReservation] {
        rows.map { row in
            let tags = Self.makeTags(
                from: row.selectedOptionsSnapshot,
                fallback: row.referenceTitle
            )

            return PastReservation(
                id: row.id,
                salonName: row.shopName,
                visitedAt: row.slotStartAt,
                thumbnailURL: row.attachedImageURL.flatMap(URL.init(string:)),
                thumbnailName: Self.fallbackAssetName(id: row.id, seed: row.referenceTitle),
                tags: tags,
                reviewStatus: .writable
            )
        }
    }

    private static func makeDDay(target: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let nowDay = calendar.startOfDay(for: now)
        let targetDay = calendar.startOfDay(for: target)
        return max(0, calendar.dateComponents([.day], from: nowDay, to: targetDay).day ?? 0)
    }

    private static func mapStatusLabel(_ status: String) -> String {
        switch status {
        case "PENDING_DEPOSIT":
            return "예약금 대기"
        case "DEPOSIT_PAID":
            return "예약금 결제"
        case "CONFIRMED":
            return "예약 확정"
        case "SERVICE_CONFIRMED":
            return "시술 확정"
        case "BALANCE_PAID":
            return "잔금 결제"
        case "COMPLETED":
            return "방문 완료"
        case "USER_CANCELLED":
            return "고객 취소"
        case "SHOP_CANCELLED":
            return "샵 취소"
        case "EXPIRED":
            return "만료"
        default:
            return "예약 상태"
        }
    }

    private static func makeTags(from snapshot: [String: Int], fallback: String) -> [String] {
        let tags = snapshot
            .sorted { $0.key.localizedCompare($1.key) == .orderedAscending }
            .prefix(3)
            .map { key, value in
                value > 0 ? "\(key) x\(value)" : key
            }

        if tags.isEmpty {
            return [fallback]
        }
        return Array(tags)
    }

    private static func fallbackAssetName(id: UUID, seed: String) -> String {
        let candidates = ["natural", "french", "chic_modern", "glitter_pearl", "lovely", "hip"]
        let sum = (id.uuidString + seed).unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return candidates[sum % candidates.count]
    }
}
