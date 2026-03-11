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
    func prepareNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) async -> NailGenListResponse?
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

    func prepareNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) async -> NailGenListResponse? {
        _ = limit
        _ = likedOnly
        return nil
    }
}

@MainActor
final class FittedAIImagesViewModel: ObservableObject {
    private enum LoadFailureHandling {
        case standard
        case restoreOnCancellation
    }

    private enum FetchApplicationMode {
        case replace
        case append
        case mergeFirstPage

        var logSource: String {
            switch self {
            case .replace:
                return "replace"
            case .append:
                return "append"
            case .mergeFirstPage:
                return "merge"
            }
        }
    }

    private enum FirstPageReadySource: String {
        case network
    }

    private struct ThumbnailPrefetchKey: Hashable {
        let url: URL
        let width: Int
        let height: Int
        let destination: NailImagePrefetchDestination
    }

    private struct FetchPageResult {
        let response: NailGenListResponse
        let items: [FittedAIImageItem]
        let detailItemsByID: [UUID: FittedAIImageDetailItem]
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
    private static let leadingThumbnailPrefetchCount: Int = 12
    private static let appendedThumbnailPrefetchCount: Int = 12
    private static let nearFutureThumbnailPrefetchCount: Int = 9

    struct DetailLoadResult: Equatable {
        let generatedURL: URL?
        let handURL: URL?
        let referenceURL: URL?
        let shape: NailGenShape?
        let extensionMode: NailGenExtensionMode?
        let parentJobId: UUID?
        let refinementTurn: Int
        let isLiked: Bool
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
        let createdAt: Date
        var isLiked: Bool

        var id: UUID { jobId }
        var imageURL: URL? { thumbnailURL }
        var thumbnailSourceForLog: String {
            guard let thumbnailURL else { return "missing" }
            let raw = thumbnailURL.absoluteString
            if raw.contains("/storage/v1/object/public/nail-results-thumb-public/") {
                return "stored"
            }
            return "fallback"
        }

        var shortJobID: String {
            String(jobId.uuidString.prefix(8))
        }
    }

    struct FittedAIImageDetailItem: Identifiable, Equatable {
        let jobId: UUID
        let thumbnailURL: URL?
        let generatedImageURL: URL?
        let shape: NailGenShape?
        let extensionMode: NailGenExtensionMode?
        let createdAt: Date
        let parentJobId: UUID?
        let refinementTurn: Int
        var isLiked: Bool

        var id: UUID { jobId }
        var generatedImageURLForDetail: URL? { generatedImageURL ?? thumbnailURL }

        var isRefined: Bool {
            refinementTurn > 0 || parentJobId != nil
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
    private let imagePrefetch: NailImagePrefetchClosure
    private let pageSize: Int
    private var allNextCursor: String?
    private var likedNextCursor: String?
    private var didLoadAll: Bool = false
    private var didLoadLiked: Bool = false
    private var allLoadGeneration: Int = 0
    private var likedLoadGeneration: Int = 0
    private var inFlightPageFetchTasks: [PageFetchKey: Task<FetchPageResult, Error>] = [:]
    private var thumbnailTargetSize: CGSize?
    private var thumbnailPrefetchKeys: Set<ThumbnailPrefetchKey> = []
    private var allItemIndexByID: [UUID: Int] = [:]
    private var likedItemIndexByID: [UUID: Int] = [:]
    private var detailItemsByID: [UUID: FittedAIImageDetailItem] = [:]
    private var detailLoadTasksByID: [UUID: Task<DetailLoadResult, Error>] = [:]
    private var cachedDetailLoadResultsByID: [UUID: DetailLoadResult] = [:]
    private var allLastPrefetchAnchor: Int?
    private var likedLastPrefetchAnchor: Int?
    private var resultsTabEnteredAt: Date?
    private var didLogFirstThumbnailDisplay: Bool = false
    private var didLogFirstScreenPrefetch: Bool = false
    private var isLoadMoreArmed: Bool = false
    private var didLogLoadMoreArmed: Bool = false
    private var didLogInitialLoadMoreBlocked: Bool = false

    init(
        pageSize: Int = 18,
        imagePrefetch: @escaping NailImagePrefetchClosure = NailImagePipeline.prefetch
    ) {
        self.pageSize = max(1, min(pageSize, 50))
        self.imagePrefetch = imagePrefetch
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

    func updateThumbnailTargetSize(_ targetSize: CGSize) {
        let normalized = Self.normalizedThumbnailTargetSize(targetSize)
        guard let normalized else { return }
        let didChangeTargetSize = thumbnailTargetSize != normalized
        guard didChangeTargetSize else { return }

        thumbnailTargetSize = normalized
        if didChangeTargetSize {
            thumbnailPrefetchKeys.removeAll()
            allLastPrefetchAnchor = nil
            likedLastPrefetchAnchor = nil
        }
        prefetchLeadingThumbnails(for: selectedFilter)
    }

    func updateScrollOffset(_ offsetY: CGFloat) {
        guard !isLoadMoreArmed else { return }
        guard let targetSize = thumbnailTargetSize else { return }

        let threshold = targetSize.height + 1
        guard offsetY >= threshold else { return }

        isLoadMoreArmed = true
        guard !didLogLoadMoreArmed else { return }
        didLogLoadMoreArmed = true
        AppLog.ui.info(
            "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_load_more_armed offset=\(Int(offsetY.rounded()), privacy: .public)"
        )
    }

    func recordScreenEntered() {
        resultsTabEnteredAt = Date()
        didLogFirstThumbnailDisplay = false
        didLogFirstScreenPrefetch = false
        resetLoadMoreArming()
        clearThumbnailPrefetchKeys(destination: .memoryCache)
        setLastPrefetchAnchor(nil, for: selectedFilter)

        AppLog.ui.info(
            "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_entered filter=\(self.selectedFilter.rawValue, privacy: .public) items=\(self.items.count, privacy: .public)"
        )

        prefetchLeadingThumbnails(for: selectedFilter)
    }

    func recordThumbnailDisplayed(jobId: UUID, source: String) {
        guard !didLogFirstThumbnailDisplay else { return }
        didLogFirstThumbnailDisplay = true

        let elapsedMilliseconds: Int
        if let referenceAt = resultsTabEnteredAt {
            elapsedMilliseconds = max(Int(Date().timeIntervalSince(referenceAt) * 1_000), 0)
        } else {
            elapsedMilliseconds = -1
        }

        AppLog.ui.info(
            "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_first_thumbnail_displayed job=\(String(jobId.uuidString.prefix(8)), privacy: .public) elapsed_ms=\(elapsedMilliseconds, privacy: .public)"
        )
        AppLog.ui.info(
            "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_first_thumbnail_source job=\(String(jobId.uuidString.prefix(8)), privacy: .public) source=\(source, privacy: .public)"
        )
    }

    func loadIfNeeded() async {
        guard !currentDidLoad else { return }
        await loadInitial(for: selectedFilter, force: false)
    }

    func setFilter(_ filter: ListFilter) async {
        guard selectedFilter != filter else { return }
        selectedFilter = filter
        resetLoadMoreArming()

        if !didLoad(filter: filter) {
            await loadInitial(for: filter, force: false)
        } else {
            prefetchLeadingThumbnails(for: filter)
        }
    }

    func refresh() async {
        await loadInitial(
            for: selectedFilter,
            force: true,
            failureHandling: .restoreOnCancellation,
            mergeOnForce: true
        )
    }

    func retry() async {
        await loadInitial(for: selectedFilter, force: true, mergeOnForce: false)
    }

    func shouldTriggerLoadMore(currentItemID: UUID) -> Bool {
        guard nextCursor(for: selectedFilter) != nil else { return false }
        guard loadMoreTriggerItemID(for: selectedFilter) == currentItemID else { return false }
        guard isLoadMoreArmed else {
            if !didLogInitialLoadMoreBlocked {
                didLogInitialLoadMoreBlocked = true
                AppLog.ui.info(
                    "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_load_more_blocked reason=initial_viewport"
                )
            }
            return false
        }
        return true
    }

    func loadMoreIfNeeded(currentItemID: UUID) async {
        let filter = selectedFilter
        guard !isLoading(for: filter), !isLoadingMore(for: filter) else { return }
        guard let nextCursor = nextCursor(for: filter) else { return }
        let requestGeneration = loadGeneration(for: filter)
        guard loadMoreTriggerItemID(for: filter) == currentItemID else { return }

        setLoadingMore(true, for: filter)
        defer { setLoadingMore(false, for: filter) }

        do {
            AppLog.ui.info(
                "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_load_more_started current_count=\(self.items(for: filter).count, privacy: .public) cursor_present=true"
            )
            let result = try await fetchPage(filter: filter, cursor: nextCursor)
            guard requestGeneration == loadGeneration(for: filter) else { return }
            applyFetchResult(result, for: filter, mode: .append)
            setError(nil, for: filter)
            setDidLoad(true, for: filter)
        } catch {
            guard requestGeneration == loadGeneration(for: filter) else { return }
            if Self.isCancellationLikeError(error) { return }
            setError(Self.listLoadErrorMessage, for: filter)
            setDidLoad(true, for: filter)
        }
    }

    func prefetchNearFutureThumbnails(currentItemID: UUID) {
        guard let targetSize = thumbnailTargetSize else { return }
        let filter = selectedFilter
        let currentItems = items(for: filter)
        guard let index = itemIndexByID(for: filter)[currentItemID] else { return }

        let nextAnchor = index / 3
        guard lastPrefetchAnchor(for: filter) != nextAnchor else { return }
        setLastPrefetchAnchor(nextAnchor, for: filter)

        let nextItems = currentItems.dropFirst(index + 1).prefix(Self.nearFutureThumbnailPrefetchCount)
        prefetchThumbnailItems(Array(nextItems), targetSize: targetSize, destination: .memoryCache)
    }

    func isDeleting(jobId: UUID) -> Bool {
        deletingJobIDs.contains(jobId)
    }

    func isLikeUpdating(jobId: UUID) -> Bool {
        likingJobIDs.contains(jobId)
    }

    func fetchDetailLoadResult(
        jobId: UUID,
        fallbackGeneratedURL: URL?
    ) async throws -> DetailLoadResult {
        if let cached = cachedDetailLoadResultsByID[jobId] {
            return cached
        }

        if let task = detailLoadTasksByID[jobId] {
            let result = try await task.value
            cachedDetailLoadResultsByID[jobId] = result
            detailLoadTasksByID[jobId] = nil
            return result
        }

        let task = makeDetailLoadTask(jobId: jobId, fallbackGeneratedURL: fallbackGeneratedURL)
        detailLoadTasksByID[jobId] = task
        let result = try await task.value
        cachedDetailLoadResultsByID[jobId] = result
        detailLoadTasksByID[jobId] = nil
        return result
    }

    func prefetchDetailLoadResult(
        jobId: UUID,
        fallbackGeneratedURL: URL?
    ) {
        guard cachedDetailLoadResultsByID[jobId] == nil else { return }
        guard detailLoadTasksByID[jobId] == nil else { return }

        detailLoadTasksByID[jobId] = makeDetailLoadTask(
            jobId: jobId,
            fallbackGeneratedURL: fallbackGeneratedURL
        )
    }

    private func makeDetailLoadTask(
        jobId: UUID,
        fallbackGeneratedURL: URL?
    ) -> Task<DetailLoadResult, Error> {
        guard let service else {
            return Task {
                throw EdgeAPIError(statusCode: -1, message: "서비스가 연결되지 않았습니다.", errorId: nil)
            }
        }

        let fallbackItem = detailItemsByID[jobId]
        return Task {
            let response = try await service.getNailGenerationJobStatus(
                jobId: jobId,
                includeInputs: true
            )
            let generatedURL = response.resultImageURL.flatMap(URL.init(string:)) ?? fallbackGeneratedURL
            let handURL = response.handImageURL.flatMap(URL.init(string:))
            let referenceURL = response.referenceImageURL.flatMap(URL.init(string:))
            return DetailLoadResult(
                generatedURL: generatedURL,
                handURL: handURL,
                referenceURL: referenceURL,
                shape: Self.parseShape(from: response.shape) ?? fallbackItem?.shape,
                extensionMode: response.extensionMode ?? fallbackItem?.extensionMode,
                parentJobId: response.parentJobId.flatMap(UUID.init(uuidString:)) ?? fallbackItem?.parentJobId,
                refinementTurn: response.refinementTurn ?? fallbackItem?.refinementTurn ?? 0,
                isLiked: response.isLiked ?? fallbackItem?.isLiked ?? false
            )
        }
    }

    func detailItem(for jobId: UUID) -> FittedAIImageDetailItem? {
        detailItemsByID[jobId]
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
            detailItemsByID = detailItemsByID.filter { !targetIDs.contains($0.key) }
            for targetID in targetIDs {
                detailLoadTasksByID[targetID]?.cancel()
                detailLoadTasksByID[targetID] = nil
                cachedDetailLoadResultsByID[targetID] = nil
            }

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
        let previousDetailItem = detailItemsByID[jobId]

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
            if let previousDetailItem {
                detailItemsByID[jobId] = previousDetailItem
            }
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
        failureHandling: LoadFailureHandling = .standard,
        mergeOnForce: Bool = false
    ) async {
        guard !isLoading(for: filter) else { return }
        if !force, isLoadingMore(for: filter) { return }
        if didLoad(filter: filter) && !force { return }
        guard service != nil else { return }
        let requestGeneration = force ? bumpLoadGeneration(for: filter) : loadGeneration(for: filter)

        let snapshot: ListStateSnapshot?
        if force && failureHandling == .restoreOnCancellation {
            snapshot = makeSnapshot(for: filter)
        } else {
            snapshot = nil
        }

        setLoading(true, for: filter)
        defer { setLoading(false, for: filter) }

        if force {
            setNextCursor(nil, for: filter)
        }

        do {
            let result = try await fetchPage(filter: filter, cursor: nil)
            guard requestGeneration == loadGeneration(for: filter) else { return }
            let applicationMode = refreshApplicationMode(
                for: filter,
                force: force,
                mergeOnForce: mergeOnForce
            )
            applyFetchResult(result, for: filter, mode: applicationMode)
            if !force {
                logFirstPageReady(source: .network, filter: filter, count: result.items.count)
            }
            setError(nil, for: filter)
            setDidLoad(true, for: filter)
            if force {
                let traceId = AppLog.makeErrorId()
                AppLog.api.info(
                    "\(AppLog.prefix(traceId, "API")) refresh_success filter=\(filter.rawValue, privacy: .public) items=\(result.items.count, privacy: .public) mode=\(applicationMode.logSource, privacy: .public)"
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
                    let applicationMode = refreshApplicationMode(
                        for: filter,
                        force: force,
                        mergeOnForce: mergeOnForce
                    )
                    applyFetchResult(retriedResult, for: filter, mode: applicationMode)
                    setError(nil, for: filter)
                    setDidLoad(true, for: filter)
                    let traceId = AppLog.makeErrorId()
                    AppLog.api.info(
                        "\(AppLog.prefix(traceId, "API")) refresh_success filter=\(filter.rawValue, privacy: .public) items=\(retriedResult.items.count, privacy: .public) mode=\(applicationMode.logSource, privacy: .public) attempt=retry_after_cancel"
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
            let detailItems = response.items.map(Self.makeDetailItem)

            return FetchPageResult(
                response: response,
                items: response.items.map(Self.makeItem),
                detailItemsByID: Dictionary(uniqueKeysWithValues: detailItems.map { ($0.jobId, $0) }),
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
        mode: FetchApplicationMode
    ) {
        registerDetailItems(result.detailItemsByID)
        logThumbnailAvailability(result.items, for: filter, source: mode.logSource)
        let previousItems = items(for: filter)
        let appendedItems: [FittedAIImageItem]
        switch mode {
        case .replace:
            setItems(result.items, for: filter)
            appendedItems = result.items
        case .append:
            let existing = Set(previousItems.map(\.jobId))
            let newItems = result.items.filter { !existing.contains($0.jobId) }
            let appended = previousItems + newItems
            setItems(appended, for: filter)
            appendedItems = newItems
        case .mergeFirstPage:
            let mergedItems = mergeFirstPageItems(
                existing: previousItems,
                fetchedFirstPage: result.items
            )
            setItems(mergedItems, for: filter)
            appendedItems = []
        }

        switch mode {
        case .replace, .mergeFirstPage:
            prefetchLeadingThumbnails(for: filter)
        case .append:
            prefetchAppendedThumbnails(appendedItems)
        }
        setNextCursor(result.nextCursor, for: filter)
    }

    private func prefetchLeadingThumbnails(for filter: ListFilter) {
        guard let targetSize = thumbnailTargetSize else { return }
        let leadingItems = Array(items(for: filter).prefix(Self.leadingThumbnailPrefetchCount))
        let queuedCount = prefetchThumbnailItems(leadingItems, targetSize: targetSize, destination: .memoryCache)
        guard queuedCount > 0, !didLogFirstScreenPrefetch else { return }
        didLogFirstScreenPrefetch = true
        AppLog.ui.info(
            "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_first_screen_prefetch_queued filter=\(filter.rawValue, privacy: .public) count=\(queuedCount, privacy: .public)"
        )
    }

    private func prefetchAppendedThumbnails(_ appendedItems: [FittedAIImageItem]) {
        guard let targetSize = thumbnailTargetSize else { return }
        let prioritizedItems = Array(appendedItems.prefix(Self.appendedThumbnailPrefetchCount))
        _ = prefetchThumbnailItems(prioritizedItems, targetSize: targetSize, destination: .memoryCache)
    }

    @discardableResult
    private func prefetchThumbnailItems(
        _ items: [FittedAIImageItem],
        targetSize: CGSize,
        destination: NailImagePrefetchDestination
    ) -> Int {
        let normalizedSize = Self.normalizedThumbnailTargetSize(targetSize)
        guard let normalizedSize else { return 0 }

        var urlsToPrefetch: [URL] = []
        for url in items.compactMap(\.imageURL) {
            let key = ThumbnailPrefetchKey(
                url: url,
                width: Int(normalizedSize.width),
                height: Int(normalizedSize.height),
                destination: destination
            )

            guard thumbnailPrefetchKeys.insert(key).inserted else { continue }
            urlsToPrefetch.append(url)
        }

        guard !urlsToPrefetch.isEmpty else { return 0 }
        imagePrefetch(
            urlsToPrefetch,
            normalizedSize,
            .fill,
            destination
        )
        return urlsToPrefetch.count
    }

    private static func normalizedThumbnailTargetSize(_ targetSize: CGSize?) -> CGSize? {
        guard let targetSize else { return nil }
        let width = floor(targetSize.width)
        let height = floor(targetSize.height)
        guard width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
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

    private func loadMoreTriggerItemID(for filter: ListFilter) -> UUID? {
        let currentItems = items(for: filter)
        guard !currentItems.isEmpty else { return nil }
        let thresholdIndex = max(currentItems.count - 6, 0)
        guard currentItems.indices.contains(thresholdIndex) else { return nil }
        return currentItems[thresholdIndex].id
    }

    private func refreshApplicationMode(
        for filter: ListFilter,
        force: Bool,
        mergeOnForce: Bool
    ) -> FetchApplicationMode {
        guard force, mergeOnForce, filter == .all, !items(for: filter).isEmpty else { return .replace }
        return .mergeFirstPage
    }

    private func clearThumbnailPrefetchKeys(destination: NailImagePrefetchDestination) {
        thumbnailPrefetchKeys = thumbnailPrefetchKeys.filter { $0.destination != destination }
    }

    private func resetLoadMoreArming() {
        isLoadMoreArmed = false
        didLogLoadMoreArmed = false
        didLogInitialLoadMoreBlocked = false
    }

    private func logThumbnailAvailability(
        _ items: [FittedAIImageItem],
        for filter: ListFilter,
        source: String
    ) {
        guard !items.isEmpty else { return }
        let missingCount = items.filter { $0.thumbnailURL == nil }.count
        guard missingCount > 0 else { return }

        AppLog.ui.info(
            "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_missing_thumbnails filter=\(filter.rawValue, privacy: .public) source=\(source, privacy: .public) missing=\(missingCount, privacy: .public) total=\(items.count, privacy: .public)"
        )
    }

    private func logFirstPageReady(
        source: FirstPageReadySource,
        filter: ListFilter,
        count: Int
    ) {
        AppLog.ui.info(
            "\(AppLog.prefix(AppLog.makeErrorId(), "UI")) results_tab_first_page_ready filter=\(filter.rawValue, privacy: .public) source=\(source.rawValue, privacy: .public) items=\(count, privacy: .public)"
        )
    }

    private func applyLikeState(jobId: UUID, isLiked: Bool) {
        if let index = allItems.firstIndex(where: { $0.jobId == jobId }) {
            allItems[index].isLiked = isLiked
        }

        if var detailItem = detailItemsByID[jobId] {
            detailItem.isLiked = isLiked
            detailItemsByID[jobId] = detailItem
        }

        if let cached = cachedDetailLoadResultsByID[jobId] {
            cachedDetailLoadResultsByID[jobId] = DetailLoadResult(
                generatedURL: cached.generatedURL,
                handURL: cached.handURL,
                referenceURL: cached.referenceURL,
                shape: cached.shape,
                extensionMode: cached.extensionMode,
                parentJobId: cached.parentJobId,
                refinementTurn: cached.refinementTurn,
                isLiked: isLiked
            )
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

    private func mergeFirstPageItems(
        existing: [FittedAIImageItem],
        fetchedFirstPage: [FittedAIImageItem]
    ) -> [FittedAIImageItem] {
        guard !existing.isEmpty else { return fetchedFirstPage }
        guard !fetchedFirstPage.isEmpty else { return [] }

        let fetchedIDs = Set(fetchedFirstPage.map(\.jobId))
        let lastOverlapIndex = existing.lastIndex { item in
            fetchedIDs.contains(item.jobId)
        }

        let tail: [FittedAIImageItem]
        if let lastOverlapIndex {
            tail = Array(existing.dropFirst(lastOverlapIndex + 1))
        } else {
            tail = existing.filter { !fetchedIDs.contains($0.jobId) }
        }

        var merged: [FittedAIImageItem] = []
        var seenIDs: Set<UUID> = []
        for item in fetchedFirstPage + tail {
            guard seenIDs.insert(item.jobId).inserted else { continue }
            merged.append(item)
        }
        return merged
    }

    private func registerDetailItems(_ fetchedDetailItemsByID: [UUID: FittedAIImageDetailItem]) {
        guard !fetchedDetailItemsByID.isEmpty else { return }
        for (jobId, detailItem) in fetchedDetailItemsByID {
            detailItemsByID[jobId] = detailItem
        }
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
            allItemIndexByID = Self.makeIndexMap(items)
        case .liked:
            likedItems = items
            likedItemIndexByID = Self.makeIndexMap(items)
        }
    }

    private func itemIndexByID(for filter: ListFilter) -> [UUID: Int] {
        switch filter {
        case .all:
            return allItemIndexByID
        case .liked:
            return likedItemIndexByID
        }
    }

    private func lastPrefetchAnchor(for filter: ListFilter) -> Int? {
        switch filter {
        case .all:
            return allLastPrefetchAnchor
        case .liked:
            return likedLastPrefetchAnchor
        }
    }

    private func setLastPrefetchAnchor(_ anchor: Int?, for filter: ListFilter) {
        switch filter {
        case .all:
            allLastPrefetchAnchor = anchor
        case .liked:
            likedLastPrefetchAnchor = anchor
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
        return FittedAIImageItem(
            jobId: item.jobId,
            thumbnailURL: item.thumbnailImageURL.flatMap(URL.init(string:)),
            createdAt: item.createdAt,
            isLiked: item.isLiked
        )
    }

    static func makeDetailItem(_ item: NailGenListItemResponse) -> FittedAIImageDetailItem {
        let shape = parseShape(from: item.shape)

        return FittedAIImageDetailItem(
            jobId: item.jobId,
            thumbnailURL: item.thumbnailImageURL.flatMap(URL.init(string:)),
            generatedImageURL: item.resultImageURL.flatMap(URL.init(string:)),
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

    private static func makeIndexMap(_ items: [FittedAIImageItem]) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: items.enumerated().map { ($0.element.id, $0.offset) })
    }

}

#if DEBUG
extension FittedAIImagesViewModel {
    static func previewState(
        selectedFilter: ListFilter = .all,
        allItems: [FittedAIImageItem]? = nil,
        likedItems: [FittedAIImageItem]? = nil,
        isLoadingAll: Bool = false,
        isLoadingLiked: Bool = false,
        allErrorMessage: String? = nil,
        likedErrorMessage: String? = nil,
        didLoadAll: Bool = true,
        didLoadLiked: Bool = true
    ) -> FittedAIImagesViewModel {
        let viewModel = FittedAIImagesViewModel()
        let resolvedAllItems = allItems ?? previewItems()
        let resolvedLikedItems = likedItems ?? resolvedAllItems.filter(\.isLiked)

        viewModel.selectedFilter = selectedFilter
        viewModel.allItems = resolvedAllItems
        viewModel.likedItems = resolvedLikedItems
        viewModel.detailItemsByID = Dictionary(
            uniqueKeysWithValues: resolvedAllItems.map { ($0.jobId, previewDetailItem(from: $0)) }
        )
        viewModel.isLoadingAll = isLoadingAll
        viewModel.isLoadingLiked = isLoadingLiked
        viewModel.allErrorMessage = allErrorMessage
        viewModel.likedErrorMessage = likedErrorMessage
        viewModel.didLoadAll = didLoadAll
        viewModel.didLoadLiked = didLoadLiked
        return viewModel
    }

    static func previewItems(count: Int = 9) -> [FittedAIImageItem] {
        (0..<count).map { index in
            FittedAIImageItem(
                jobId: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1)) ?? UUID(),
                thumbnailURL: PreviewFixtures.imageURL(name: "fit-thumb-\(index)", hue: CGFloat(index) * 0.08),
                createdAt: Date().addingTimeInterval(Double(-index) * 3_600),
                isLiked: index.isMultiple(of: 3)
            )
        }
    }

    static func previewDetailItem(
        from item: FittedAIImageItem,
        shape: NailGenShape? = .almond,
        extensionMode: NailGenExtensionMode? = .extend
    ) -> FittedAIImageDetailItem {
        FittedAIImageDetailItem(
            jobId: item.jobId,
            thumbnailURL: item.thumbnailURL,
            generatedImageURL: PreviewFixtures.imageURL(name: "fit-full-\(item.shortJobID)", hue: 0.08),
            shape: shape,
            extensionMode: extensionMode,
            createdAt: item.createdAt,
            parentJobId: nil,
            refinementTurn: 0,
            isLiked: item.isLiked
        )
    }
}
#endif
