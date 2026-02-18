//
//  QuoteResponseListViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class QuoteResponseListViewModel: ObservableObject {
    struct RequestSummary: Equatable {
        let id: UUID
        let status: QuoteRequestStatus
        let targetMode: QuoteTargetMode
        let preferredDate: String
        let requestNote: String

        var statusText: String {
            switch status {
            case .open:
                return "응답 확인 중"
            case .selected:
                return "샵 선택 완료"
            case .closed:
                return "종료"
            }
        }

        var targetModeText: String {
            switch targetMode {
            case .regionAll:
                return "지역 전체"
            case .selectedShops:
                return "선택 샵"
            }
        }
    }

    struct ImageSummary: Equatable {
        let userHandImageURL: String?
        let aiInputHandImageURL: String?
        let aiResultImageURL: String?
    }

    struct ResponseRow: Identifiable, Equatable {
        let id: UUID
        let targetStatus: QuoteTargetStatus
        let sentAt: Date?
        let respondedAt: Date?
        let selectedAt: Date?
        let shopName: String
        let shopAddress: String
        let responseID: UUID?
        let finalPrice: Int?
        let changeItems: [QuoteChangeItem]
        let memo: String?

        var hasResponse: Bool {
            responseID != nil
        }

        var targetStatusText: String {
            switch targetStatus {
            case .requested:
                return "요청 전송"
            case .responded:
                return "응답 도착"
            case .selected:
                return "선택된 샵"
            case .closed:
                return "마감"
            }
        }

        var finalPriceText: String {
            guard let finalPrice else { return "미응답" }
            return NumberFormatter.krw.string(from: NSNumber(value: finalPrice)) ?? "₩\(finalPrice)"
        }

        var changeItemsText: String {
            if changeItems.isEmpty { return "변동 항목 없음" }
            return changeItems.map(\.title).joined(separator: ", ")
        }

        var sentAtText: String {
            guard let sentAt else { return "-" }
            return Self.dateFormatter.string(from: sentAt)
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yyyy.MM.dd HH:mm"
            return formatter
        }()
    }

    @Published private(set) var requestSummary: RequestSummary?
    @Published private(set) var imageSummary: ImageSummary?
    @Published private(set) var responses: [ResponseRow] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var selectingTargetIDs: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    private weak var service: (any FittedAIImagesServicing)?
    private let quoteRequestID: UUID
    private var didLoadOnce = false

    init(quoteRequestID: UUID) {
        self.quoteRequestID = quoteRequestID
    }

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
            let response = try await service.fetchQuoteResponseList(quoteRequestId: quoteRequestID)
            requestSummary = RequestSummary(
                id: response.quoteRequest.id,
                status: response.quoteRequest.status,
                targetMode: response.quoteRequest.targetMode,
                preferredDate: response.quoteRequest.preferredDate,
                requestNote: response.quoteRequest.requestNote
            )
            imageSummary = ImageSummary(
                userHandImageURL: response.images.userHandImage,
                aiInputHandImageURL: response.images.aiInputHandImage,
                aiResultImageURL: response.images.aiResultImage
            )
            responses = response.responses.map(Self.mapResponse)
            errorMessage = nil
            didLoadOnce = true
        } catch {
            errorMessage = "견적 응답을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            didLoadOnce = true
        }
    }

    func canSelectTarget(_ targetID: UUID) -> Bool {
        guard let requestSummary else { return false }
        guard requestSummary.status == .open else { return false }
        guard !selectingTargetIDs.contains(targetID) else { return false }

        guard let row = responses.first(where: { $0.id == targetID }) else { return false }
        guard row.hasResponse else { return false }
        guard row.targetStatus == .responded || row.targetStatus == .requested else { return false }
        return true
    }

    func selectTarget(_ targetID: UUID) async {
        guard canSelectTarget(targetID) else { return }
        guard let service else { return }

        selectingTargetIDs.insert(targetID)
        defer { selectingTargetIDs.remove(targetID) }

        do {
            _ = try await service.selectQuoteResponse(
                quoteRequestId: quoteRequestID,
                targetId: targetID
            )
            toastMessage = "샵 선택이 완료되었어요."
            await refresh()
        } catch {
            errorMessage = "샵 선택에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    func dismissToast() {
        toastMessage = nil
    }

    private static func mapResponse(_ item: QuoteResponseItemResponse) -> ResponseRow {
        ResponseRow(
            id: item.targetId,
            targetStatus: item.targetStatus,
            sentAt: item.sentAt,
            respondedAt: item.respondedAt,
            selectedAt: item.selectedAt,
            shopName: item.shop?.name ?? "샵 정보 없음",
            shopAddress: item.shop?.address ?? "",
            responseID: item.response?.id,
            finalPrice: item.response?.finalPrice,
            changeItems: item.response?.changeItems ?? [],
            memo: item.response?.memo
        )
    }
}

private extension NumberFormatter {
    static let krw: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.numberStyle = .currency
        formatter.currencyCode = "KRW"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
