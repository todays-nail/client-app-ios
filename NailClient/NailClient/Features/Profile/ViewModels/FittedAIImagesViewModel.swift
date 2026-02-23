//
//  FittedAIImagesViewModel.swift
//  NailClient
//

import Foundation
import Combine
import CoreGraphics
import OSLog

@MainActor
protocol FittedAIImagesServicing: AnyObject {
    func fetchCompletedNailGenerationList(
        limit: Int,
        cursor: String?,
        likedOnly: Bool
    ) async throws -> NailGenListResponse
    func getNailGenerationJobStatus(
        jobId: UUID,
        includeInputs: Bool
    ) async throws -> NailGenJobStatusResponse
    func cachedNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) -> NailGenListResponse?
    func setCachedNailGenerationFirstPage(
        _ response: NailGenListResponse,
        limit: Int,
        likedOnly: Bool
    )
    func preloadNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) async
    func setNailGenerationLike(jobId: UUID, isLiked: Bool) async throws -> NailGenLikeResponse
    func deleteNailGeneration(jobId: UUID) async throws -> NailGenDeleteResponse
}

extension AppViewModel: FittedAIImagesServicing {}

extension FittedAIImagesServicing {
    func getNailGenerationJobStatus(
        jobId: UUID,
        includeInputs: Bool
    ) async throws -> NailGenJobStatusResponse {
        _ = jobId
        _ = includeInputs
        throw EdgeAPIError(statusCode: -1, message: "상세 이미지 조회를 지원하지 않는 서비스입니다.", errorId: nil)
    }

    func cachedNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) -> NailGenListResponse? {
        _ = limit
        _ = likedOnly
        return nil
    }

    func setCachedNailGenerationFirstPage(
        _ response: NailGenListResponse,
        limit: Int,
        likedOnly: Bool
    ) {
        _ = response
        _ = limit
        _ = likedOnly
    }

    func preloadNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) async {
        _ = limit
        _ = likedOnly
    }
}

@MainActor
final class FittedAIImagesViewModel: ObservableObject {
    private enum LoadFailureHandling {
        case standard
        case restoreOnCancellation
    }

    private struct FetchPageResult {
        let response: NailGenListResponse
        let items: [FittedAIImageItem]
        let nextCursor: String?
    }

    private struct PageFetchKey: Hashable {
        let filter: ListFilter
        let cursor: String?
    }

    private struct ListStateSnapshot {
        let items: [FittedAIImageItem]
        let nextCursor: String?
        let errorMessage: String?
        let didLoad: Bool
    }

    private static let listLoadErrorMessage = "이미지 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
    private static let thumbnailPrefetchCount: Int = 12
    private static let thumbnailPrefetchSize = CGSize(width: 180, height: 180)

    struct DetailImageSet: Equatable {
        let generatedURL: URL?
        let handURL: URL?
        let referenceURL: URL?
    }

    enum ListFilter: String, CaseIterable, Identifiable {
        case all
        case liked

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "전체"
            case .liked:
                return "좋아요"
            }
        }

        var likedOnly: Bool {
            self == .liked
        }
    }

    struct FittedAIImageItem: Identifiable, Equatable {
        let jobId: UUID
        let thumbnailURL: URL?
        let fullImageURL: URL?
        let shape: NailGenShape?
        let extensionMode: NailGenExtensionMode?
        let createdAt: Date
        let parentJobId: UUID?
        let refinementTurn: Int
        var isLiked: Bool

        var id: UUID { jobId }
        var imageURL: URL? { thumbnailURL ?? fullImageURL }
        var generatedImageURLForDetail: URL? { fullImageURL ?? thumbnailURL }

        var isRefined: Bool {
            refinementTurn > 0 || parentJobId != nil
        }

        var shortJobID: String {
            String(jobId.uuidString.prefix(8))
        }
    }

    @Published private(set) var selectedFilter: ListFilter = .all
    @Published private(set) var allItems: [FittedAIImageItem] = []
    @Published private(set) var likedItems: [FittedAIImageItem] = []
    @Published private(set) var isLoadingAll: Bool = false
    @Published private(set) var isLoadingLiked: Bool = false
    @Published private(set) var isLoadingMoreAll: Bool = false
    @Published private(set) var isLoadingMoreLiked: Bool = false
    @Published private(set) var allErrorMessage: String?
    @Published private(set) var likedErrorMessage: String?
    @Published private(set) var deletingJobIDs: Set<UUID> = []
    @Published private(set) var likingJobIDs: Set<UUID> = []

    private weak var service: (any FittedAIImagesServicing)?
    private let pageSize: Int
    private var allNextCursor: String?
    private var likedNextCursor: String?
    private var didLoadAll: Bool = false
    private var didLoadLiked: Bool = false
    private var allLoadGeneration: Int = 0
    private var likedLoadGeneration: Int = 0
    private var inFlightPageFetchTasks: [PageFetchKey: Task<FetchPageResult, Error>] = [:]

    init(pageSize: Int = 20) {
        self.pageSize = max(1, min(pageSize, 50))
    }

    var items: [FittedAIImageItem] {
        switch selectedFilter {
        case .all:
            return allItems
        case .liked:
            return likedItems
        }
    }

    var isLoading: Bool {
        switch selectedFilter {
        case .all:
            return isLoadingAll
        case .liked:
            return isLoadingLiked
        }
    }

    var isLoadingMore: Bool {
        switch selectedFilter {
        case .all:
            return isLoadingMoreAll
        case .liked:
            return isLoadingMoreLiked
        }
    }

    var errorMessage: String? {
        switch selectedFilter {
        case .all:
            return allErrorMessage
        case .liked:
            return likedErrorMessage
        }
    }

    var shouldShowEmptyState: Bool {
        currentDidLoad && !isLoading && items.isEmpty && errorMessage == nil
    }

    func bind(service: any FittedAIImagesServicing) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !currentDidLoad else { return }
        await loadInitial(for: selectedFilter, force: false)
    }

    func setFilter(_ filter: ListFilter) async {
        guard selectedFilter != filter else { return }
        selectedFilter = filter

        if !didLoad(filter: filter) {
            await loadInitial(for: filter, force: false)
        }
    }

    func refresh() async {
        await loadInitial(
            for: selectedFilter,
            force: true,
            failureHandling: .restoreOnCancellation
        )
    }

    func retry() async {
        await loadInitial(for: selectedFilter, force: true)
    }

    func loadMoreIfNeeded(currentItemID: UUID) async {
        let filter = selectedFilter
        guard !isLoading(for: filter), !isLoadingMore(for: filter) else { return }
        guard let nextCursor = nextCursor(for: filter) else { return }
        let requestGeneration = loadGeneration(for: filter)

        let currentItems = items(for: filter)
        guard let index = currentItems.firstIndex(where: { $0.id == currentItemID }) else { return }

        let thresholdIndex = max(currentItems.count - 6, 0)
        guard index >= thresholdIndex else { return }

        setLoadingMore(true, for: filter)
        defer { setLoadingMore(false, for: filter) }

        do {
            let result = try await fetchPage(filter: filter, cursor: nextCursor)
            guard requestGeneration == loadGeneration(for: filter) else { return }
            applyFetchResult(result, for: filter, replaceItems: false)
            setError(nil, for: filter)
            setDidLoad(true, for: filter)
        } catch {
            guard requestGeneration == loadGeneration(for: filter) else { return }
            if Self.isCancellationLikeError(error) { return }
            setError(Self.listLoadErrorMessage, for: filter)
            setDidLoad(true, for: filter)
        }
    }

    func isDeleting(jobId: UUID) -> Bool {
        deletingJobIDs.contains(jobId)
    }

    func isLikeUpdating(jobId: UUID) -> Bool {
        likingJobIDs.contains(jobId)
    }

    func fetchDetailImageSet(
        jobId: UUID,
        fallbackGeneratedURL: URL?
    ) async throws -> DetailImageSet {
        guard let service else {
            throw EdgeAPIError(statusCode: -1, message: "서비스가 연결되지 않았습니다.", errorId: nil)
        }

        let response = try await service.getNailGenerationJobStatus(
            jobId: jobId,
            includeInputs: true
        )
        let generatedURL = response.resultImageURL.flatMap(URL.init(string:)) ?? fallbackGeneratedURL
        let handURL = response.handImageURL.flatMap(URL.init(string:))
        let referenceURL = response.referenceImageURL.flatMap(URL.init(string:))
        return DetailImageSet(
            generatedURL: generatedURL,
            handURL: handURL,
            referenceURL: referenceURL
        )
    }

    func delete(jobId: UUID) async -> Bool {
        guard let service else { return false }
        guard deletingJobIDs.contains(jobId) == false else { return false }

        deletingJobIDs.insert(jobId)
        defer { deletingJobIDs.remove(jobId) }

        do {
            let response = try await service.deleteNailGeneration(jobId: jobId)
            let deletedIDs = Set(response.deletedJobIDs)
            let targetIDs = deletedIDs.isEmpty ? Set([jobId]) : deletedIDs

            allItems.removeAll { targetIDs.contains($0.jobId) }
            likedItems.removeAll { targetIDs.contains($0.jobId) }

            setError(nil, for: selectedFilter)
            return true
        } catch {
            setError("이미지 삭제에 실패했어요. 잠시 후 다시 시도해 주세요.", for: selectedFilter)
            return false
        }
    }

    func toggleLike(jobId: UUID) async -> Bool {
        guard let currentItem = item(by: jobId) else { return false }
        return await setLike(jobId: jobId, isLiked: !currentItem.isLiked)
    }

    func setLike(jobId: UUID, isLiked: Bool) async -> Bool {
        guard let service else { return false }
        guard likingJobIDs.contains(jobId) == false else { return false }
        guard let existingItem = item(by: jobId) else { return false }

        if existingItem.isLiked == isLiked {
            return true
        }

        let previousAllItems = allItems
        let previousLikedItems = likedItems

        likingJobIDs.insert(jobId)
        applyLikeState(jobId: jobId, isLiked: isLiked)

        defer { likingJobIDs.remove(jobId) }

        do {
            let response = try await service.setNailGenerationLike(jobId: jobId, isLiked: isLiked)
            applyLikeState(jobId: response.jobId, isLiked: response.isLiked)
            setError(nil, for: selectedFilter)
            return true
        } catch {
            allItems = previousAllItems
            likedItems = previousLikedItems
            setError("좋아요 상태 변경에 실패했어요. 잠시 후 다시 시도해 주세요.", for: selectedFilter)
            return false
        }
    }

    private var currentDidLoad: Bool {
        didLoad(filter: selectedFilter)
    }

    private func didLoad(filter: ListFilter) -> Bool {
        switch filter {
        case .all:
            return didLoadAll
        case .liked:
            return didLoadLiked
        }
    }

    private func setDidLoad(_ didLoad: Bool, for filter: ListFilter) {
        switch filter {
        case .all:
            didLoadAll = didLoad
        case .liked:
            didLoadLiked = didLoad
        }
    }

    private func loadGeneration(for filter: ListFilter) -> Int {
        switch filter {
        case .all:
            return allLoadGeneration
        case .liked:
            return likedLoadGeneration
        }
    }

    @discardableResult
    private func bumpLoadGeneration(for filter: ListFilter) -> Int {
        switch filter {
        case .all:
            allLoadGeneration += 1
            return allLoadGeneration
        case .liked:
            likedLoadGeneration += 1
            return likedLoadGeneration
        }
    }

    private func loadInitial(
        for filter: ListFilter,
        force: Bool,
        failureHandling: LoadFailureHandling = .standard
    ) async {
        guard !isLoading(for: filter) else { return }
        if !force, isLoadingMore(for: filter) { return }
        if didLoad(filter: filter) && !force { return }
        guard let service else { return }
        let requestGeneration = force ? bumpLoadGeneration(for: filter) : loadGeneration(for: filter)

        let snapshot: ListStateSnapshot?
        if force && failureHandling == .restoreOnCancellation {
            snapshot = makeSnapshot(for: filter)
        } else {
            snapshot = nil
        }

        let cachedFirstPage: FetchPageResult?
        if !force,
           let cached = service.cachedNailGenerationFirstPage(limit: pageSize, likedOnly: filter.likedOnly) {
            cachedFirstPage = FetchPageResult(
                response: cached,
                items: cached.items.map(Self.makeItem),
                nextCursor: cached.nextCursor
            )
        } else {
            cachedFirstPage = nil
        }

        if let cachedFirstPage {
            applyFetchResult(cachedFirstPage, for: filter, replaceItems: true)
            setError(nil, for: filter)
            setDidLoad(true, for: filter)
        }

        let shouldShowLoading = cachedFirstPage == nil
        if shouldShowLoading {
            setLoading(true, for: filter)
        }
        defer {
            if shouldShowLoading {
                setLoading(false, for: filter)
            }
        }

        if force {
            setNextCursor(nil, for: filter)
        }
        if force {
            setItems([], for: filter)
        }

        do {
            let result = try await fetchPage(filter: filter, cursor: nil)
            guard requestGeneration == loadGeneration(for: filter) else { return }
            applyFetchResult(result, for: filter, replaceItems: true)
            service.setCachedNailGenerationFirstPage(
                result.response,
                limit: pageSize,
                likedOnly: filter.likedOnly
            )
            setError(nil, for: filter)
            setDidLoad(true, for: filter)
            if force {
                let traceId = AppLog.makeErrorId()
                AppLog.api.info(
                    "\(AppLog.prefix(traceId, "API")) refresh_success filter=\(filter.rawValue, privacy: .public) items=\(result.items.count, privacy: .public)"
                )
            }
        } catch {
            guard requestGeneration == loadGeneration(for: filter) else { return }
            if force,
               failureHandling == .restoreOnCancellation,
               Self.isCancellationLikeError(error) {
                do {
                    let retriedResult = try await fetchPage(filter: filter, cursor: nil)
                    guard requestGeneration == loadGeneration(for: filter) else { return }
                    applyFetchResult(retriedResult, for: filter, replaceItems: true)
                    service.setCachedNailGenerationFirstPage(
                        retriedResult.response,
                        limit: pageSize,
                        likedOnly: filter.likedOnly
                    )
                    setError(nil, for: filter)
                    setDidLoad(true, for: filter)
                    let traceId = AppLog.makeErrorId()
                    AppLog.api.info(
                        "\(AppLog.prefix(traceId, "API")) refresh_success filter=\(filter.rawValue, privacy: .public) items=\(retriedResult.items.count, privacy: .public) attempt=retry_after_cancel"
                    )
                    return
                } catch {
                    guard requestGeneration == loadGeneration(for: filter) else { return }
                    if let snapshot,
                       Self.isCancellationLikeError(error) {
                        restoreSnapshot(snapshot, for: filter)
                        setError(nil, for: filter)
                        return
                    }
                    setError(Self.listLoadErrorMessage, for: filter)
                    setDidLoad(true, for: filter)
                    return
                }
            }

            if cachedFirstPage != nil && !force {
                setError(nil, for: filter)
                setDidLoad(true, for: filter)
                return
            }

            if failureHandling == .restoreOnCancellation,
               let snapshot,
               Self.isCancellationLikeError(error) {
                restoreSnapshot(snapshot, for: filter)
                setError(nil, for: filter)
                return
            }

            setError(Self.listLoadErrorMessage, for: filter)
            setDidLoad(true, for: filter)
        }
    }

    private func fetchPage(
        filter: ListFilter,
        cursor: String?
    ) async throws -> FetchPageResult {
        let key = PageFetchKey(filter: filter, cursor: cursor)
        if let inFlightTask = inFlightPageFetchTasks[key] {
            return try await inFlightTask.value
        }

        let task = Task<FetchPageResult, Error> { @MainActor [weak self] in
            guard let self else {
                throw CancellationError()
            }
            guard let service = self.service else {
                throw EdgeAPIError(statusCode: -1, message: "서비스가 연결되지 않았습니다.", errorId: nil)
            }

            let response = try await service.fetchCompletedNailGenerationList(
                limit: self.pageSize,
                cursor: cursor,
                likedOnly: filter.likedOnly
            )

            return FetchPageResult(
                response: response,
                items: response.items.map(Self.makeItem),
                nextCursor: response.nextCursor
            )
        }
        inFlightPageFetchTasks[key] = task
        defer { inFlightPageFetchTasks[key] = nil }

        return try await task.value
    }

    private func applyFetchResult(
        _ result: FetchPageResult,
        for filter: ListFilter,
        replaceItems: Bool
    ) {
        if replaceItems {
            setItems(result.items, for: filter)
        } else {
            let existing = Set(items(for: filter).map(\.jobId))
            let appended = items(for: filter) + result.items.filter { !existing.contains($0.jobId) }
            setItems(appended, for: filter)
        }

        prefetchInitialThumbnails(for: filter)
        setNextCursor(result.nextCursor, for: filter)
    }

    private func prefetchInitialThumbnails(for filter: ListFilter) {
        let urls = Array(items(for: filter).prefix(Self.thumbnailPrefetchCount))
            .compactMap { $0.imageURL }
        NailImagePipeline.prefetch(
            urls: urls,
            targetSize: Self.thumbnailPrefetchSize,
            resizeMode: .fill
        )
    }

    private func makeSnapshot(for filter: ListFilter) -> ListStateSnapshot {
        ListStateSnapshot(
            items: items(for: filter),
            nextCursor: nextCursor(for: filter),
            errorMessage: errorMessage(for: filter),
            didLoad: didLoad(filter: filter)
        )
    }

    private func restoreSnapshot(_ snapshot: ListStateSnapshot, for filter: ListFilter) {
        setItems(snapshot.items, for: filter)
        setNextCursor(snapshot.nextCursor, for: filter)
        setError(snapshot.errorMessage, for: filter)
        setDidLoad(snapshot.didLoad, for: filter)
    }

    private static func isCancellationLikeError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && nsError.code == URLError.cancelled.rawValue
    }

    private func item(by jobId: UUID) -> FittedAIImageItem? {
        allItems.first(where: { $0.jobId == jobId })
            ?? likedItems.first(where: { $0.jobId == jobId })
    }

    private func applyLikeState(jobId: UUID, isLiked: Bool) {
        if let index = allItems.firstIndex(where: { $0.jobId == jobId }) {
            allItems[index].isLiked = isLiked
        }

        if isLiked {
            if let index = likedItems.firstIndex(where: { $0.jobId == jobId }) {
                likedItems[index].isLiked = true
            } else if var target = item(by: jobId) {
                target.isLiked = true
                likedItems.append(target)
                likedItems.sort(by: Self.sortByNewest)
            }
        } else {
            likedItems.removeAll { $0.jobId == jobId }
        }
    }

    private static func sortByNewest(_ lhs: FittedAIImageItem, _ rhs: FittedAIImageItem) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.jobId.uuidString > rhs.jobId.uuidString
    }

    private func items(for filter: ListFilter) -> [FittedAIImageItem] {
        switch filter {
        case .all:
            return allItems
        case .liked:
            return likedItems
        }
    }

    private func setItems(_ items: [FittedAIImageItem], for filter: ListFilter) {
        switch filter {
        case .all:
            allItems = items
        case .liked:
            likedItems = items
        }
    }

    private func nextCursor(for filter: ListFilter) -> String? {
        switch filter {
        case .all:
            return allNextCursor
        case .liked:
            return likedNextCursor
        }
    }

    private func setNextCursor(_ cursor: String?, for filter: ListFilter) {
        switch filter {
        case .all:
            allNextCursor = cursor
        case .liked:
            likedNextCursor = cursor
        }
    }

    private func isLoading(for filter: ListFilter) -> Bool {
        switch filter {
        case .all:
            return isLoadingAll
        case .liked:
            return isLoadingLiked
        }
    }

    private func setLoading(_ isLoading: Bool, for filter: ListFilter) {
        switch filter {
        case .all:
            isLoadingAll = isLoading
        case .liked:
            isLoadingLiked = isLoading
        }
    }

    private func isLoadingMore(for filter: ListFilter) -> Bool {
        switch filter {
        case .all:
            return isLoadingMoreAll
        case .liked:
            return isLoadingMoreLiked
        }
    }

    private func setLoadingMore(_ isLoadingMore: Bool, for filter: ListFilter) {
        switch filter {
        case .all:
            isLoadingMoreAll = isLoadingMore
        case .liked:
            isLoadingMoreLiked = isLoadingMore
        }
    }

    private func setError(_ message: String?, for filter: ListFilter) {
        switch filter {
        case .all:
            allErrorMessage = message
        case .liked:
            likedErrorMessage = message
        }
    }

    private func errorMessage(for filter: ListFilter) -> String? {
        switch filter {
        case .all:
            return allErrorMessage
        case .liked:
            return likedErrorMessage
        }
    }

    static func makeItem(_ item: NailGenListItemResponse) -> FittedAIImageItem {
        let shape = parseShape(from: item.shape)

        return FittedAIImageItem(
            jobId: item.jobId,
            thumbnailURL: item.thumbnailImageURL.flatMap(URL.init(string:)),
            fullImageURL: item.resultImageURL.flatMap(URL.init(string:)),
            shape: shape,
            extensionMode: item.extensionMode,
            createdAt: item.createdAt,
            parentJobId: item.parentJobId,
            refinementTurn: item.refinementTurn,
            isLiked: item.isLiked
        )
    }

    private static func parseShape(from rawValue: String?) -> NailGenShape? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else { return nil }
        return NailGenShape(rawValue: raw)
    }

}
