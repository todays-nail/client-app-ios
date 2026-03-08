//
//  AINailGenerationDetailItemTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct AINailGenerationDetailItemTests {
    @Test
    func makeAutoOpenedDetailItem_현재생성상태를상세아이템으로매핑한다() throws {
        let jobID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let parentJobID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let createdAt = Date(timeIntervalSince1970: 1_736_000_000)
        let resultURL = try #require(URL(string: "https://example.com/result.png"))

        let viewModel = AINailGenerationViewModel.previewState(
            selectedShape: .square,
            selectedExtensionOption: .extend,
            resultImageURL: resultURL,
            currentJobId: jobID,
            parentJobId: parentJobID,
            refinementTurn: 2,
            isSubmitting: false,
            statusMessage: "생성 완료"
        )

        let item = try #require(viewModel.makeAutoOpenedDetailItem(createdAt: createdAt))
        #expect(item.jobId == jobID)
        #expect(item.fullImageURL == resultURL)
        #expect(item.thumbnailURL == nil)
        #expect(item.shape == .square)
        #expect(item.extensionMode == .extend)
        #expect(item.createdAt == createdAt)
        #expect(item.parentJobId == parentJobID)
        #expect(item.refinementTurn == 2)
        #expect(item.isLiked == false)
    }

    @Test
    func makeAutoOpenedDetailItem_필수값이없으면_nil을반환한다() {
        let viewModel = AINailGenerationViewModel()
        #expect(viewModel.makeAutoOpenedDetailItem() == nil)
    }
}
