//
//  FittedAIImagesViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
protocol FittedAIImagesServicing: AnyObject {
    func fetchCompletedNailGenerationList(
        limit: Int,
        cursor: String?
    ) async throws -> NailGenListResponse
    func deleteNailGeneration(jobId: UUID) async throws -> NailGenDeleteResponse
}

extension AppViewModel: FittedAIImagesServicing {}

@MainActor
final class FittedAIImagesViewModel: ObservableObject {
    struct FittedAIImageItem: Identifiable, Equatable {
        let jobId: UUID
        let imageURL: URL?
        let shapeText: String?
        let promptText: String
        let createdAt: Date
        let parentJobId: UUID?
        let refinementTurn: Int

        var id: UUID { jobId }

        var isRefined: Bool {
            refinementTurn > 0 || parentJobId != nil
        }

        var refinementBadgeText: String {
            if isRefined {
                return "수정본 \(max(1, refinementTurn))차"
            }
            return "원본"
        }

        var promptSummary: String {
            if promptText.isEmpty {
                return "프롬프트 입력 없음"
            }
            return promptText
        }

        var shortJobID: String {
            String(jobId.uuidString.prefix(8))
        }
    }

    @Published private(set) var items: [FittedAIImageItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var deletingJobIDs: Set<UUID> = []

    private weak var service: (any FittedAIImagesServicing)?
    private let pageSize: Int
    private var nextCursor: String?
    private var didLoadOnce: Bool = false

    init(pageSize: Int = 20) {
        self.pageSize = max(1, min(pageSize, 50))
    }

    func bind(service: any FittedAIImagesServicing) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        await loadInitial(force: false)
    }

    func refresh() async {
        await loadInitial(force: true)
    }

    func retry() async {
        await loadInitial(force: true)
    }

    func loadMoreIfNeeded(currentItemID: UUID) async {
        guard !isLoading, !isLoadingMore else { return }
        guard let nextCursor else { return }
        guard let index = items.firstIndex(where: { $0.id == currentItemID }) else { return }
        let thresholdIndex = max(items.count - 6, 0)
        guard index >= thresholdIndex else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        _ = await fetchPage(cursor: nextCursor, replaceItems: false)
    }

    var shouldShowEmptyState: Bool {
        didLoadOnce && !isLoading && items.isEmpty && errorMessage == nil
    }

    var refinedCount: Int {
        items.filter(\.isRefined).count
    }

    var originalCount: Int {
        max(0, items.count - refinedCount)
    }

    var latestCreatedAt: Date? {
        items.map(\.createdAt).max()
    }

    func isDeleting(jobId: UUID) -> Bool {
        deletingJobIDs.contains(jobId)
    }

    func delete(jobId: UUID) async -> Bool {
        guard let service else { return false }
        guard deletingJobIDs.contains(jobId) == false else { return false }

        deletingJobIDs.insert(jobId)
        defer { deletingJobIDs.remove(jobId) }

        do {
            let response = try await service.deleteNailGeneration(jobId: jobId)
            let deletedIDs = Set(response.deletedJobIDs)
            if deletedIDs.isEmpty {
                items.removeAll { $0.jobId == jobId }
            } else {
                items.removeAll { deletedIDs.contains($0.jobId) }
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "이미지 삭제에 실패했어요. 잠시 후 다시 시도해 주세요."
            return false
        }
    }

    private func loadInitial(force: Bool) async {
        guard !isLoading, !isLoadingMore else { return }
        if didLoadOnce && !force { return }
        guard service != nil else { return }

        isLoading = true
        defer { isLoading = false }

        nextCursor = nil
        if force {
            items = []
        }

        _ = await fetchPage(cursor: nil, replaceItems: true)
    }

    private func fetchPage(cursor: String?, replaceItems: Bool) async -> Bool {
        guard let service else { return false }

        do {
            let response = try await service.fetchCompletedNailGenerationList(
                limit: pageSize,
                cursor: cursor
            )

            let mappedItems = response.items.map(Self.mapItem)
            if replaceItems {
                items = mappedItems
            } else {
                let existing = Set(items.map(\.jobId))
                items.append(contentsOf: mappedItems.filter { !existing.contains($0.jobId) })
            }

            nextCursor = response.nextCursor
            errorMessage = nil
            didLoadOnce = true
            return true
        } catch {
            errorMessage = "이미지 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            didLoadOnce = true
            return false
        }
    }

    private static func mapItem(_ item: NailGenListItemResponse) -> FittedAIImageItem {
        let normalizedPrompt = (item.userPrompt ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shapeText = displayShape(from: item.shape)

        return FittedAIImageItem(
            jobId: item.jobId,
            imageURL: item.resultImageURL.flatMap(URL.init(string:)),
            shapeText: shapeText,
            promptText: normalizedPrompt,
            createdAt: item.createdAt,
            parentJobId: item.parentJobId,
            refinementTurn: item.refinementTurn
        )
    }

    private static func displayShape(from rawValue: String?) -> String? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else { return nil }
        switch raw {
        case "almond":
            return "아몬드"
        case "square":
            return "스퀘어"
        case "round":
            return "라운드"
        default:
            return raw
        }
    }
}
