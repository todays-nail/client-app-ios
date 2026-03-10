import Foundation
@testable import NailClient

@MainActor
final class FittedAIImagesServiceSpy: FittedAIImagesServicing {
    struct CacheKey: Hashable {
        let limit: Int
        let likedOnly: Bool
    }

    let listResponse: NailGenListResponse
    var deleteHandler: ((UUID) async throws -> NailGenDeleteResponse)?
    var deleteError: Error?
    var fetchResultsQueue: [Result<NailGenListResponse, Error>] = []
    var fetchHandler: ((Int, Int, String?, Bool) async throws -> NailGenListResponse)?
    var cachedFirstPageResponses: [CacheKey: NailGenListResponse] = [:]
    var prepareFirstPageHandler: ((Int, Bool) async -> NailGenListResponse?)?
    var preloadCallCount: Int = 0
    var prepareCallCount: Int = 0
    private(set) var fetchCallCount: Int = 0

    init(listResponse: NailGenListResponse) {
        self.listResponse = listResponse
    }

    func fetchCompletedNailGenerationList(
        limit: Int,
        cursor: String?,
        likedOnly: Bool
    ) async throws -> NailGenListResponse {
        fetchCallCount += 1
        let call = fetchCallCount
        if let fetchHandler {
            return try await fetchHandler(call, limit, cursor, likedOnly)
        }

        if !fetchResultsQueue.isEmpty {
            return try fetchResultsQueue.removeFirst().get()
        }

        return listResponse
    }

    func cachedNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) -> NailGenListResponse? {
        cachedFirstPageResponses[.init(limit: limit, likedOnly: likedOnly)]
    }

    func setCachedNailGenerationFirstPage(
        _ response: NailGenListResponse,
        limit: Int,
        likedOnly: Bool
    ) {
        cachedFirstPageResponses[.init(limit: limit, likedOnly: likedOnly)] = response
    }

    func preloadNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) async {
        _ = limit
        _ = likedOnly
        preloadCallCount += 1
    }

    func prepareNailGenerationFirstPage(
        limit: Int,
        likedOnly: Bool
    ) async -> NailGenListResponse? {
        prepareCallCount += 1
        if let prepareFirstPageHandler {
            return await prepareFirstPageHandler(limit, likedOnly)
        }
        return cachedFirstPageResponses[.init(limit: limit, likedOnly: likedOnly)]
    }

    func setNailGenerationLike(jobId: UUID, isLiked: Bool) async throws -> NailGenLikeResponse {
        NailGenLikeResponse(ok: true, jobId: jobId, isLiked: isLiked)
    }

    func deleteNailGeneration(jobId: UUID) async throws -> NailGenDeleteResponse {
        if let deleteError {
            throw deleteError
        }
        if let deleteHandler {
            return try await deleteHandler(jobId)
        }
        return NailGenDeleteResponse(ok: true, deletedJobIDs: [jobId])
    }
}
