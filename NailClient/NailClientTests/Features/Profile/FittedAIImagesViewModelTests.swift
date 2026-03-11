//
//  FittedAIImagesViewModelTests.swift
//  NailClientTests
//

import CoreGraphics
import Foundation
import Testing
@testable import NailClient

@MainActor
struct FittedAIImagesViewModelTests {
    @Test
    func 모양과연장모드가_상세아이템설정값으로매핑된다() async {
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

        #expect(viewModel.detailItem(for: naturalID)?.shape == .almond)
        #expect(viewModel.detailItem(for: naturalID)?.extensionMode == .natural)
        #expect(viewModel.detailItem(for: extendID)?.shape == .square)
        #expect(viewModel.detailItem(for: extendID)?.extensionMode == .extend)
        #expect(viewModel.detailItem(for: unknownID)?.shape == nil)
        #expect(viewModel.detailItem(for: unknownID)?.extensionMode == nil)
    }

    @Test
    func 상세로드결과는_status응답의메타와이미지URL을우선사용한다() async throws {
        let jobID = UUID(uuidString: "abababab-abab-4aba-8aba-abababababab")!
        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [
                    NailGenerationTestFixtures.makeListItem(
                        jobId: jobID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        resultImageURL: "https://example.com/list-full.jpg",
                        thumbnailImageURL: "https://example.com/list-thumb.jpg",
                        shape: "almond",
                        extensionMode: .natural,
                        isLiked: false
                    )
                ],
                nextCursor: nil
            )
        )
        service.statusResponse = NailGenerationTestFixtures.makeStatusResponse(
            status: .completed,
            resultImageURL: "https://example.com/status-full.jpg",
            handImageURL: "https://example.com/hand.jpg",
            referenceImageURL: "https://example.com/reference.jpg",
            resultDisplayImageURL: "https://example.com/status-display.jpg",
            handDisplayImageURL: "https://example.com/hand-display.jpg",
            referenceDisplayImageURL: "https://example.com/reference-display.jpg",
            parentJobId: "12121212-1212-4121-8121-121212121212",
            refinementTurn: 2,
            shape: "square",
            extensionMode: .extend,
            isLiked: true
        )

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let detail = try await viewModel.fetchDetailLoadResult(
            jobId: jobID,
            fallbackGeneratedURL: URL(string: "https://example.com/fallback.jpg")
        )

        #expect(detail.generatedURL?.absoluteString == "https://example.com/status-display.jpg")
        #expect(detail.handURL?.absoluteString == "https://example.com/hand-display.jpg")
        #expect(detail.referenceURL?.absoluteString == "https://example.com/reference-display.jpg")
        #expect(detail.generatedSource == .display)
        #expect(detail.handSource == .display)
        #expect(detail.referenceSource == .display)
        #expect(detail.shape == .square)
        #expect(detail.extensionMode == .extend)
        #expect(detail.parentJobId?.uuidString.lowercased() == "12121212-1212-4121-8121-121212121212")
        #expect(detail.refinementTurn == 2)
        #expect(detail.isLiked == true)
    }

    @Test
    func 상세로드결과는_status응답에메타가없으면_목록상세아이템값으로폴백한다() async throws {
        let parentJobID = UUID(uuidString: "34343434-3434-4343-8343-343434343434")!
        let jobID = UUID(uuidString: "cdcdcdcd-cdcd-4cdc-8cdc-cdcdcdcdcdcd")!
        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [
                    NailGenerationTestFixtures.makeListItem(
                        jobId: jobID,
                        parentJobId: parentJobID,
                        refinementTurn: 1,
                        resultImageURL: "https://example.com/list-full.jpg",
                        thumbnailImageURL: "https://example.com/list-thumb.jpg",
                        shape: "almond",
                        extensionMode: .natural,
                        isLiked: true
                    )
                ],
                nextCursor: nil
            )
        )
        service.statusResponse = NailGenerationTestFixtures.makeStatusResponse(
            status: .completed,
            resultImageURL: nil,
            handImageURL: nil,
            referenceImageURL: nil,
            parentJobId: nil,
            refinementTurn: nil,
            shape: nil,
            extensionMode: nil,
            isLiked: nil
        )

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let detail = try await viewModel.fetchDetailLoadResult(
            jobId: jobID,
            fallbackGeneratedURL: URL(string: "https://example.com/fallback.jpg")
        )

        #expect(detail.generatedURL?.absoluteString == "https://example.com/fallback.jpg")
        #expect(detail.generatedSource == .original)
        #expect(detail.handURL == nil)
        #expect(detail.handSource == .original)
        #expect(detail.referenceURL == nil)
        #expect(detail.referenceSource == .original)
        #expect(detail.shape == .almond)
        #expect(detail.extensionMode == .natural)
        #expect(detail.parentJobId == parentJobID)
        #expect(detail.refinementTurn == 1)
        #expect(detail.isLiked == true)
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

        #expect(viewModel.items.map(\.jobId) == [refreshedID, initialID])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadIfNeeded는_직접fetch결과로_목록을채운다() async {
        let fetchedID = UUID(uuidString: "20202020-2020-4202-8202-202020202020")!
        let fetchedResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: fetchedID, parentJobId: nil, refinementTurn: 0)],
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: fetchedResponse)

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        #expect(viewModel.items.map(\.jobId) == [fetchedID])
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

        #expect(viewModel.items.map(\.jobId) == [refreshedID, initialID])
        #expect(viewModel.errorMessage == nil)
        #expect(service.fetchCallCount == 3)
    }

    @Test
    func refresh_all필터는_새첫페이지를상단병합하고_tail을유지한다() async {
        let initialIDs = makeUUIDs(prefix: "74747474-7474-4747-8747", count: 8)
        let refreshedIDs = makeUUIDs(prefix: "75757575-7575-4757-8757", count: 2)

        let initialResponse = NailGenListResponse(
            items: [
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[0], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[1], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[2], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[3], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[4], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[5], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[6], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[7], parentJobId: nil, refinementTurn: 0),
            ],
            nextCursor: "cursor-initial"
        )
        let refreshedResponse = NailGenListResponse(
            items: [
                NailGenerationTestFixtures.makeListItem(jobId: refreshedIDs[0], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: refreshedIDs[1], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[3], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[4], parentJobId: nil, refinementTurn: 0),
                NailGenerationTestFixtures.makeListItem(jobId: initialIDs[5], parentJobId: nil, refinementTurn: 0),
            ],
            nextCursor: "cursor-refresh"
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .success(refreshedResponse)
        ]

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()
        await viewModel.refresh()

        #expect(viewModel.items.map(\.jobId) == [
            refreshedIDs[0],
            refreshedIDs[1],
            initialIDs[3],
            initialIDs[4],
            initialIDs[5],
            initialIDs[6],
            initialIDs[7]
        ])
    }

    @Test
    func refresh_all필터는_overlap이없어도_기존unique목록을tail에유지한다() async {
        let initialIDs = makeUUIDs(prefix: "76767676-7676-4767-8767", count: 4)
        let refreshedIDs = makeUUIDs(prefix: "78787878-7878-4787-8787", count: 3)

        let initialResponse = NailGenListResponse(
            items: initialIDs.map { NailGenerationTestFixtures.makeListItem(jobId: $0, parentJobId: nil, refinementTurn: 0) },
            nextCursor: "cursor-initial"
        )
        let refreshedResponse = NailGenListResponse(
            items: refreshedIDs.map { NailGenerationTestFixtures.makeListItem(jobId: $0, parentJobId: nil, refinementTurn: 0) },
            nextCursor: "cursor-refresh"
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchResultsQueue = [
            .success(initialResponse),
            .success(refreshedResponse)
        ]

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()
        await viewModel.refresh()

        #expect(viewModel.items.map(\.jobId) == refreshedIDs + initialIDs)
    }

    @Test
    func refresh_liked필터는_여전히_replace로동기화한다() async {
        let initialAllID = UUID(uuidString: "79797979-7979-4797-8797-797979797979")!
        let initialLikedID = UUID(uuidString: "7a7a7a7a-7a7a-47a7-87a7-7a7a7a7a7a7a")!
        let refreshedLikedID = UUID(uuidString: "7b7b7b7b-7b7b-47b7-87b7-7b7b7b7b7b7b")!

        let initialAllResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialAllID, parentJobId: nil, refinementTurn: 0, isLiked: false)],
            nextCursor: nil
        )
        let initialLikedResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: initialLikedID, parentJobId: nil, refinementTurn: 0, isLiked: true)],
            nextCursor: nil
        )
        let refreshedLikedResponse = NailGenListResponse(
            items: [NailGenerationTestFixtures.makeListItem(jobId: refreshedLikedID, parentJobId: nil, refinementTurn: 0, isLiked: true)],
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialAllResponse)
        service.fetchHandler = { call, _, cursor, likedOnly in
            #expect(cursor == nil)
            switch (call, likedOnly) {
            case (1, false):
                return initialAllResponse
            case (2, true):
                return initialLikedResponse
            case (3, true):
                return refreshedLikedResponse
            default:
                return refreshedLikedResponse
            }
        }

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()
        await viewModel.setFilter(.liked)
        #expect(viewModel.items.map(\.jobId) == [initialLikedID])

        await viewModel.refresh()

        #expect(viewModel.items.map(\.jobId) == [refreshedLikedID])
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
        viewModel.updateThumbnailTargetSize(CGSize(width: 129, height: 129))
        viewModel.updateScrollOffset(130)

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

        #expect(viewModel.items.map(\.jobId) == [initialID])
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
        #expect(viewModel.items.map(\.jobId) == [initialID])
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
        let detailItem = try #require(viewModel.detailItem(for: jobID))
        #expect(item.imageURL?.absoluteString == thumbnailURL)
        #expect(detailItem.generatedImageURLForDetail?.absoluteString == fullURL)
    }

    @Test
    func 썸네일URL이없으면_그리드는원본으로fallback하지않고_상세만원본을사용한다() async throws {
        let jobID = UUID(uuidString: "ffffffff-1111-4fff-8fff-ffffffffffff")!
        let fullURL = "https://signed.example.com/full-only.png"

        let service = FittedAIImagesServiceSpy(
            listResponse: NailGenListResponse(
                items: [
                    NailGenerationTestFixtures.makeListItem(
                        jobId: jobID,
                        parentJobId: nil,
                        refinementTurn: 0,
                        resultImageURL: fullURL,
                        thumbnailImageURL: nil
                    )
                ],
                nextCursor: nil
            )
        )

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        let item = try #require(viewModel.items.first)
        let detailItem = try #require(viewModel.detailItem(for: jobID))
        #expect(item.imageURL == nil)
        #expect(detailItem.generatedImageURLForDetail?.absoluteString == fullURL)
    }

    @Test
    func loadMore는_임계아이템에서만_트리거된다() async {
        let ids = (0..<10).map {
            UUID(uuidString: String(format: "abababab-abab-4aba-8aba-%012d", $0 + 1)) ?? UUID()
        }
        let response = NailGenListResponse(
            items: ids.map { id in
                NailGenerationTestFixtures.makeListItem(jobId: id, parentJobId: nil, refinementTurn: 0)
            },
            nextCursor: "cursor-next"
        )

        let service = FittedAIImagesServiceSpy(listResponse: response)
        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()
        viewModel.updateThumbnailTargetSize(CGSize(width: 129, height: 129))

        #expect(viewModel.shouldTriggerLoadMore(currentItemID: ids[4]) == false)

        viewModel.updateScrollOffset(129)
        #expect(viewModel.shouldTriggerLoadMore(currentItemID: ids[4]) == false)

        viewModel.updateScrollOffset(130)
        #expect(viewModel.shouldTriggerLoadMore(currentItemID: ids[3]) == false)
        #expect(viewModel.shouldTriggerLoadMore(currentItemID: ids[4]) == true)
        #expect(viewModel.shouldTriggerLoadMore(currentItemID: ids[5]) == false)
    }

    @Test
    func 첫진입직후에는_loadMore가_arm되기전까지_임계아이템이어도_차단된다() async {
        let ids = (0..<10).map {
            UUID(uuidString: String(format: "abababab-abab-4aba-9aba-%012d", $0 + 1)) ?? UUID()
        }
        let response = NailGenListResponse(
            items: ids.map { id in
                NailGenerationTestFixtures.makeListItem(jobId: id, parentJobId: nil, refinementTurn: 0)
            },
            nextCursor: "cursor-next"
        )

        let service = FittedAIImagesServiceSpy(listResponse: response)
        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()
        viewModel.updateThumbnailTargetSize(CGSize(width: 129, height: 129))

        #expect(viewModel.shouldTriggerLoadMore(currentItemID: ids[4]) == false)
    }

    @Test
    func loadIfNeeded는_prepare응답을사용하지않고_직접fetch한다() async {
        let response = NailGenListResponse(
            items: (0..<6).map { index in
                NailGenerationTestFixtures.makeListItem(
                    jobId: UUID(uuidString: String(format: "acacacac-acac-4aca-8aca-%012d", index + 1)) ?? UUID(),
                    parentJobId: nil,
                    refinementTurn: 0,
                    resultImageURL: "https://example.com/full-\(index).png",
                    thumbnailImageURL: "https://example.com/thumb-\(index).jpg"
                )
            },
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: response)
        service.fetchHandler = { _, limit, cursor, likedOnly in
            #expect(limit == 18)
            #expect(cursor == nil)
            #expect(likedOnly == false)
            return response
        }
        service.prepareFirstPageHandler = { _, _ in response }

        let viewModel = FittedAIImagesViewModel()
        viewModel.bind(service: service)

        await viewModel.loadIfNeeded()

        #expect(service.prepareCallCount == 0)
        #expect(service.fetchCallCount == 1)
        #expect(viewModel.items.map(\.jobId) == response.items.map(\.jobId))
    }

    @Test
    func 목록로드후_썸네일크기설정시_앞12개를메모리프리패치한다() async throws {
        let fetchedResponse = NailGenListResponse(
            items: (0..<15).map { index in
                NailGenerationTestFixtures.makeListItem(
                    jobId: UUID(uuidString: String(format: "aaaaaaaa-aaaa-4aaa-8aaa-%012d", index + 1)) ?? UUID(),
                    parentJobId: nil,
                    refinementTurn: 0,
                    resultImageURL: "https://example.com/full-\(index).png",
                    thumbnailImageURL: "https://example.com/thumb-\(index).jpg"
                )
            },
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: fetchedResponse)
        let recorder = ImagePrefetchRecorder()
        let viewModel = FittedAIImagesViewModel(imagePrefetch: recorder.prefetch)
        viewModel.bind(service: service)
        await viewModel.loadIfNeeded()

        viewModel.updateThumbnailTargetSize(CGSize(width: 129, height: 129))

        let call = try #require(recorder.calls.first)
        #expect(call.urls.count == 12)
        #expect(call.targetSize == CGSize(width: 129, height: 129))
        #expect(call.destination == .memoryCache)

        #expect(recorder.calls.count == 1)
    }

    @Test
    func loadMore후에는_append된아이템을우선메모리프리패치한다() async throws {
        let initialIDs = (0..<10).map {
            UUID(uuidString: String(format: "bbbbbbbb-bbbb-4bbb-8bbb-%012d", $0 + 1)) ?? UUID()
        }
        let appendedIDs = (0..<4).map {
            UUID(uuidString: String(format: "cccccccc-cccc-4ccc-8ccc-%012d", $0 + 1)) ?? UUID()
        }

        let initialResponse = NailGenListResponse(
            items: initialIDs.enumerated().map { index, id in
                NailGenerationTestFixtures.makeListItem(
                    jobId: id,
                    parentJobId: nil,
                    refinementTurn: 0,
                    resultImageURL: "https://example.com/full-initial-\(index).png",
                    thumbnailImageURL: "https://example.com/thumb-initial-\(index).jpg"
                )
            },
            nextCursor: "cursor-next"
        )
        let loadMoreResponse = NailGenListResponse(
            items: appendedIDs.enumerated().map { index, id in
                NailGenerationTestFixtures.makeListItem(
                    jobId: id,
                    parentJobId: nil,
                    refinementTurn: 0,
                    resultImageURL: "https://example.com/full-appended-\(index).png",
                    thumbnailImageURL: "https://example.com/thumb-appended-\(index).jpg"
                )
            },
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: initialResponse)
        service.fetchHandler = { call, _, cursor, _ in
            switch call {
            case 1:
                #expect(cursor == nil)
                return initialResponse
            case 2:
                #expect(cursor == "cursor-next")
                return loadMoreResponse
            default:
                return loadMoreResponse
            }
        }

        let recorder = ImagePrefetchRecorder()
        let viewModel = FittedAIImagesViewModel(imagePrefetch: recorder.prefetch)
        viewModel.bind(service: service)
        viewModel.updateThumbnailTargetSize(CGSize(width: 129, height: 129))

        await viewModel.loadIfNeeded()
        recorder.reset()
        viewModel.updateScrollOffset(130)

        let currentItemID = try #require(initialIDs[safe: 4])
        await viewModel.loadMoreIfNeeded(currentItemID: currentItemID)

        let call = try #require(recorder.calls.first)
        #expect(call.urls.map(\.absoluteString) == appendedIDs.enumerated().map { index, _ in
            "https://example.com/thumb-appended-\(index).jpg"
        })
        #expect(call.destination == .memoryCache)
        #expect(call.targetSize == CGSize(width: 129, height: 129))
    }

    @Test
    func 셀appear시_현재인덱스이후9개를근접구간으로프리패치한다() async throws {
        let response = NailGenListResponse(
            items: (0..<20).map { index in
                NailGenerationTestFixtures.makeListItem(
                    jobId: UUID(uuidString: String(format: "dddddddd-dddd-4ddd-8ddd-%012d", index + 1)) ?? UUID(),
                    parentJobId: nil,
                    refinementTurn: 0,
                    resultImageURL: "https://example.com/full-\(index).png",
                    thumbnailImageURL: "https://example.com/thumb-\(index).jpg"
                )
            },
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: response)
        let recorder = ImagePrefetchRecorder()
        let viewModel = FittedAIImagesViewModel(imagePrefetch: recorder.prefetch)
        viewModel.bind(service: service)
        viewModel.updateThumbnailTargetSize(CGSize(width: 129, height: 129))

        await viewModel.loadIfNeeded()
        recorder.reset()

        let currentItemID = try #require(viewModel.items[safe: 11]?.jobId)
        viewModel.prefetchNearFutureThumbnails(currentItemID: currentItemID)

        let call = try #require(recorder.calls.first)
        #expect(call.urls.map(\.absoluteString) == (12..<20).map { "https://example.com/thumb-\($0).jpg" })
        #expect(call.destination == .memoryCache)
    }

    @Test
    func 근접구간프리패치는_같은anchor구간에서는_중복실행하지않는다() async {
        let response = NailGenListResponse(
            items: (0..<20).map { index in
                NailGenerationTestFixtures.makeListItem(
                    jobId: UUID(uuidString: String(format: "eeeeeeee-eeee-4eee-8eee-%012d", index + 1)) ?? UUID(),
                    parentJobId: nil,
                    refinementTurn: 0,
                    resultImageURL: "https://example.com/full-\(index).png",
                    thumbnailImageURL: "https://example.com/thumb-\(index).jpg"
                )
            },
            nextCursor: nil
        )

        let service = FittedAIImagesServiceSpy(listResponse: response)
        let recorder = ImagePrefetchRecorder()
        let viewModel = FittedAIImagesViewModel(imagePrefetch: recorder.prefetch)
        viewModel.bind(service: service)
        viewModel.updateThumbnailTargetSize(CGSize(width: 129, height: 129))

        await viewModel.loadIfNeeded()
        recorder.reset()

        viewModel.prefetchNearFutureThumbnails(currentItemID: response.items[12].jobId)
        viewModel.prefetchNearFutureThumbnails(currentItemID: response.items[13].jobId)
        viewModel.prefetchNearFutureThumbnails(currentItemID: response.items[14].jobId)

        #expect(recorder.calls.count == 1)
    }

}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private func makeUUIDs(prefix: String, count: Int) -> [UUID] {
    (0..<count).map { index in
        UUID(uuidString: "\(prefix)-\(String(format: "%012d", index + 1))") ?? UUID()
    }
}
