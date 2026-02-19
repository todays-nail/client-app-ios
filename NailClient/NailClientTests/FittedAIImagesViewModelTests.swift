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
    func 모양과연장모드가_아이템설정값으로매핑된다() async {
        let naturalID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let extendID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let unknownID = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!

        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [
                    makeItem(
                        jobId: naturalID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        shape: "almond",
                        extensionMode: .natural
                    ),
                    makeItem(
                        jobId: extendID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        shape: "square",
                        extensionMode: .extend
                    ),
                    makeItem(
                        jobId: unknownID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        shape: "unknown",
                        extensionMode: nil
                    ),
                ],
                nextCursor: nil
            )
        )
        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()

        #expect(viewModel.items.first(where: { $0.jobId == naturalID })?.shape == .almond)
        #expect(viewModel.items.first(where: { $0.jobId == naturalID })?.extensionMode == .natural)
        #expect(viewModel.items.first(where: { $0.jobId == extendID })?.shape == .square)
        #expect(viewModel.items.first(where: { $0.jobId == extendID })?.extensionMode == .extend)
        #expect(viewModel.items.first(where: { $0.jobId == unknownID })?.shape == nil)
        #expect(viewModel.items.first(where: { $0.jobId == unknownID })?.extensionMode == nil)
    }

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

    @Test
    func refresh_취소에러시_목록복원_에러미표시() async {
        let initialID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        let initialResponse = NailGenListResponse(
            items: [makeItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: "cursor-a"
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .failure(CancellationError())
        ]

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()
        #expect(viewModel.items.map(\.jobId) == [initialID])
        #expect(viewModel.errorMessage == nil)

        await viewModel.refresh()

        #expect(viewModel.items.map(\.jobId) == [initialID])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func refresh_일반에러시_기존정책유지() async {
        let initialID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let initialResponse = NailGenListResponse(
            items: [makeItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .failure(TestError.forced)
        ]

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()
        #expect(viewModel.items.map(\.jobId) == [initialID])

        await viewModel.refresh()

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.errorMessage == "이미지 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
    }

    @Test
    func retry_성공시_정상복구() async {
        let initialID = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!
        let recoveredID = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!

        let initialResponse = NailGenListResponse(
            items: [makeItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )
        let recoveredResponse = NailGenListResponse(
            items: [makeItem(jobId: recoveredID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .failure(TestError.forced),
            .success(recoveredResponse)
        ]

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()
        #expect(viewModel.items.map(\.jobId) == [initialID])

        await viewModel.refresh()
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.errorMessage == "이미지 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")

        await viewModel.retry()
        #expect(viewModel.items.map(\.jobId) == [recoveredID])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func 썸네일URL이있으면_목록은썸네일_상세는원본을사용한다() async throws {
        let jobID = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")!
        let thumbnailURL = "https://cdn.example.com/thumb.jpg"
        let fullURL = "https://signed.example.com/full.png"

        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [
                    makeItem(
                        jobId: jobID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        resultImageURL: fullURL,
                        thumbnailImageURL: thumbnailURL
                    )
                ],
                nextCursor: nil
            )
        )

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let item = try #require(viewModel.items.first)
        #expect(item.imageURL?.absoluteString == thumbnailURL)
        #expect(item.generatedImageURLForDetail?.absoluteString == fullURL)
    }

    private func makeItem(
        jobId: UUID,
        parentJobId: UUID?,
        refinementTurn: Int,
        resultImageURL: String? = nil,
        thumbnailImageURL: String? = nil,
        shape: String = "almond",
        extensionMode: NailGenExtensionMode? = .natural
    ) -> NailGenListItemResponse {
        NailGenListItemResponse(
            jobId: jobId,
            resultImageURL: resultImageURL ?? "https://example.com/\(jobId.uuidString).jpg",
            thumbnailImageURL: thumbnailImageURL,
            shape: shape,
            extensionMode: extensionMode,
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
    var fetchResultsQueue: [Result<NailGenListResponse, Error>] = []

    init(listResponse: NailGenListResponse) {
        self.listResponse = listResponse
    }

    func fetchCompletedNailGenerationList(
        limit: Int,
        cursor: String?,
        likedOnly: Bool
    ) async throws -> NailGenListResponse {
        _ = limit
        _ = cursor
        _ = likedOnly

        if !fetchResultsQueue.isEmpty {
            return try fetchResultsQueue.removeFirst().get()
        }

        return listResponse
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

private enum TestError: Error {
    case forced
    case unsupported
}
