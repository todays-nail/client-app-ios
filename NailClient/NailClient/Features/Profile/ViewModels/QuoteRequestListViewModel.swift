//
//  QuoteRequestListViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class QuoteRequestListViewModel: ObservableObject {
    struct QuoteRequestRow: Identifiable, Equatable {
        let id: UUID
        let targetMode: QuoteTargetMode
        let preferredDate: String
        let requestNote: String
        let status: QuoteRequestStatus
        let targetCount: Int
        let respondedCount: Int
        let createdAt: Date

        var targetModeText: String {
            switch targetMode {
            case .regionAll:
                return "지역 전체"
            case .selectedShops:
                return "선택 샵"
            }
        }

        var statusText: String {
            switch status {
            case .open:
                return "응답 대기"
            case .selected:
                return "샵 선택 완료"
            case .closed:
                return "종료"
            }
        }

        var responseProgressText: String {
            if targetCount <= 0 {
                return "응답 0건"
            }
            return "응답 \(respondedCount)/\(targetCount)"
        }

        var createdAtText: String {
            Self.dateTimeFormatter.string(from: createdAt)
        }

        private static let dateTimeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yyyy.MM.dd HH:mm"
            return formatter
        }()
    }

    @Published private(set) var items: [QuoteRequestRow] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private weak var service: (any FittedAIImagesServicing)?
    private var didLoadOnce = false

    func bind(service: any FittedAIImagesServicing) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        await refresh()
    }

    func refresh() async {
        guard let service else { return }
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await service.fetchQuoteRequestList(limit: 50)
            items = response.items.map(Self.mapItem)
            errorMessage = nil
            didLoadOnce = true
        } catch {
            errorMessage = "견적 요청 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            didLoadOnce = true
        }
    }

    private static func mapItem(_ item: QuoteRequestItemResponse) -> QuoteRequestRow {
        QuoteRequestRow(
            id: item.id,
            targetMode: item.targetMode,
            preferredDate: item.preferredDate,
            requestNote: item.requestNote,
            status: item.status,
            targetCount: item.targetCount ?? 0,
            respondedCount: item.respondedCount ?? 0,
            createdAt: item.createdAt
        )
    }
}
