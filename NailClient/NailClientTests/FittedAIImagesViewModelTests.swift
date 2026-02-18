//
//  FittedAIImagesViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct FittedAIImagesViewModelTests {
    @Test
    func 삭제성공시_삭제된잡들이_목록에서제거된다() async {
        let rootID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let childID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [
                    makeItem(jobId: rootID, parentJobId: nil, refinementTurn: 0),
                    makeItem(jobId: childID, parentJobId: rootID, refinementTurn: 1),
                ],
                nextCursor: nil
            )
        )
        service.deleteHandler = { _ in
            NailGenDeleteResponse(ok: true, deletedJobIDs: [rootID, childID])
        }

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let succeeded = await viewModel.delete(jobId: rootID)

        #expect(succeeded == true)
        #expect(viewModel.items.isEmpty)
    }

    @Test
    func 삭제응답에_deleted_ids가비어있으면_요청한잡만제거한다() async {
        let firstID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let secondID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!

        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [
                    makeItem(jobId: firstID, parentJobId: nil, refinementTurn: 0),
                    makeItem(jobId: secondID, parentJobId: nil, refinementTurn: 0),
                ],
                nextCursor: nil
            )
        )
        service.deleteHandler = { _ in
            NailGenDeleteResponse(ok: true, deletedJobIDs: [])
        }

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let succeeded = await viewModel.delete(jobId: secondID)

        #expect(succeeded == true)
        #expect(viewModel.items.map(\.jobId) == [firstID])
    }

    @Test
    func 삭제실패시_에러메시지를노출하고_목록을유지한다() async {
        let rootID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [makeItem(jobId: rootID, parentJobId: nil, refinementTurn: 0)],
                nextCursor: nil
            )
        )
        service.deleteError = TestError.forced

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let succeeded = await viewModel.delete(jobId: rootID)

        #expect(succeeded == false)
        #expect(viewModel.items.map(\.jobId) == [rootID])
        #expect(viewModel.errorMessage == "이미지 삭제에 실패했어요. 잠시 후 다시 시도해 주세요.")
    }

    private func makeItem(
        jobId: UUID,
        parentJobId: UUID?,
        refinementTurn: Int
    ) -> NailGenListItemResponse {
        NailGenListItemResponse(
            jobId: jobId,
            resultImageURL: "https://example.com/\(jobId.uuidString).jpg",
            shape: "almond",
            userPrompt: "test",
            createdAt: Date(),
            parentJobId: parentJobId,
            refinementTurn: refinementTurn
        )
    }
}

@MainActor
private final class FittedAIImagesServiceSpy: FittedAIImagesServicing {
    let listResponse: NailGenListResponse
    var deleteHandler: ((UUID) async throws -> NailGenDeleteResponse)?
    var deleteError: Error?

    init(listResponse: NailGenListResponse) {
        self.listResponse = listResponse
    }

    func fetchCompletedNailGenerationList(limit: Int, cursor: String?) async throws -> NailGenListResponse {
        _ = limit
        _ = cursor
        return listResponse
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

    func createQuoteRequest(
        jobId: UUID,
        targetType: QuoteRequestTargetType,
        regionId: UUID?,
        shopId: UUID?
    ) async throws -> QuoteRequestCreateResponse {
        _ = jobId
        _ = targetType
        _ = regionId
        _ = shopId
        throw TestError.unsupported
    }

    func fetchRegions() async throws -> RegionsListResponse {
        throw TestError.unsupported
    }

    func searchShops(query: String, limit: Int) async throws -> ShopSearchResponse {
        _ = query
        _ = limit
        throw TestError.unsupported
    }
}

private enum TestError: Error {
    case forced
    case unsupported
}
