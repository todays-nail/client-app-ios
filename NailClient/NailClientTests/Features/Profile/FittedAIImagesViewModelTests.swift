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
                    NailGenerationTestFixtures.makeListItem(
                        jobId: naturalID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        shape: "almond",
                        extensionMode: .natural
                    ),
                    NailGenerationTestFixtures.makeListItem(
                        jobId: extendID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        shape: "square",
                        extensionMode: .extend
                    ),
                    NailGenerationTestFixtures.makeListItem(
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
                    NailGenerationTestFixtures.makeListItem(jobId: rootID, parentJobId: nil, refinementTurn: 0),
                    NailGenerationTestFixtures.makeListItem(jobId: childID, parentJobId: rootID, refinementTurn: 1),
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
                    NailGenerationTestFixtures.makeListItem(jobId: firstID, parentJobId: nil, refinementTurn: 0),
                    NailGenerationTestFixtures.makeListItem(jobId: secondID, parentJobId: nil, refinementTurn: 0),
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
                items: [NailGenerationTestFixtures.makeListItem(jobId: rootID, parentJobId: nil, refinementTurn: 0)],
                nextCursor: nil
            )
        )
        service.deleteError = TestSupportError.forced

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
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
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
    func refresh_URLError취소시_목록복원_에러미표시() async {
        let initialID = UUID(uuidString: "76767676-7676-4767-8767-767676767676")!
        let initialResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: "cursor-cancel"
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .failure(URLError(.cancelled))
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
    func refresh_중_진행중인loadMore결과는_무시하고_refresh결과를유지한다() async {
        let initialID = UUID(uuidString: "12121212-1212-4121-8121-121212121212")!
        let staleLoadMoreID = UUID(uuidString: "34343434-3434-4343-8343-343434343434")!
        let refreshedID = UUID(uuidString: "56565656-5656-4565-8565-565656565656")!

        let initialResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: "cursor-next"
        )
        let staleLoadMoreResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: staleLoadMoreID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )
        let refreshedResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: refreshedID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let gate = AsyncGate()
        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchHandler = { call, _, cursor, _ in
            switch call {
            case 1:
                #expect(cursor == nil)
                return initialResponse
            case 2:
                #expect(cursor == "cursor-next")
                await gate.wait()
                return staleLoadMoreResponse
            case 3:
                #expect(cursor == nil)
                return refreshedResponse
            default:
                return refreshedResponse
            }
        }

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()
        #expect(viewModel.items.map(\.jobId) == [initialID])

        let loadMoreTask = Task {
            await viewModel.loadMoreIfNeeded(currentItemID: initialID)
        }

        for _ in 0..<50 {
            if service.fetchCallCount >= 2 { break }
            await Task.yield()
        }
        #expect(service.fetchCallCount >= 2)

        await viewModel.refresh()
        await gate.open()
        await loadMoreTask.value

        #expect(viewModel.items.map(\.jobId) == [refreshedID])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadIfNeeded_캐시히트시_즉시목록표시후_백그라운드재검증반영() async {
        let cachedID = UUID(uuidString: "10101010-1010-4101-8101-101010101010")!
        let refreshedID = UUID(uuidString: "20202020-2020-4202-8202-202020202020")!

        let cachedResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: cachedID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )
        let refreshedResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: refreshedID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let gate = AsyncGate()
        let service = FittedAIImagesServiceSpy(listResponse: refreshedResponse)
        service.cachedFirstPageResponses = [
            .init(limit: 20, likedOnly: false): cachedResponse
        ]
        service.fetchHandler = { call, _, cursor, likedOnly in
            #expect(call == 1)
            #expect(cursor == nil)
            #expect(likedOnly == false)
            await gate.wait()
            return refreshedResponse
        }

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        let loadTask = Task {
            await viewModel.loadIfNeeded()
        }

        for _ in 0..<50 {
            if !viewModel.items.isEmpty {
                break
            }
            await Task.yield()
        }

        #expect(viewModel.items.map(\.jobId) == [cachedID])
        #expect(viewModel.errorMessage == nil)

        await gate.open()
        await loadTask.value

        #expect(viewModel.items.map(\.jobId) == [refreshedID])
        #expect(viewModel.errorMessage == nil)
        #expect(service.fetchCallCount == 1)
    }

    @Test
    func refresh_취소후1회재시도성공시_최신결과로갱신한다() async {
        let initialID = UUID(uuidString: "31313131-3131-4313-8313-313131313131")!
        let refreshedID = UUID(uuidString: "41414141-4141-4414-8414-414141414141")!

        let initialResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )
        let refreshedResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: refreshedID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .failure(URLError(.cancelled)),
            .success(refreshedResponse)
        ]

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()
        #expect(viewModel.items.map(\.jobId) == [initialID])

        await viewModel.refresh()

        #expect(viewModel.items.map(\.jobId) == [refreshedID])
        #expect(viewModel.errorMessage == nil)
        #expect(service.fetchCallCount == 3)
    }

    @Test
    func loadMore_동시호출시_중복요청을억제한다() async {
        let initialID = UUID(uuidString: "51515151-5151-4515-8515-515151515151")!
        let appendedID = UUID(uuidString: "61616161-6161-4616-8616-616161616161")!

        let initialResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: "cursor-next"
        )
        let loadMoreResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: appendedID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let gate = AsyncGate()
        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchHandler = { call, _, cursor, _ in
            switch call {
            case 1:
                #expect(cursor == nil)
                return initialResponse
            case 2:
                #expect(cursor == "cursor-next")
                await gate.wait()
                return loadMoreResponse
            default:
                return loadMoreResponse
            }
        }

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let first = Task { await viewModel.loadMoreIfNeeded(currentItemID: initialID) }
        let second = Task { await viewModel.loadMoreIfNeeded(currentItemID: initialID) }

        for _ in 0..<50 {
            if service.fetchCallCount >= 2 {
                break
            }
            await Task.yield()
        }

        await gate.open()
        await first.value
        await second.value

        #expect(service.fetchCallCount == 2)
        #expect(viewModel.items.map(\.jobId) == [initialID, appendedID])
    }

    @Test
    func refresh_일반에러시_기존정책유지() async {
        let initialID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let initialResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .failure(TestSupportError.forced)
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
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )
        let recoveredResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: recoveredID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .failure(TestSupportError.forced),
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
                    NailGenerationTestFixtures.makeListItem(
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

}
