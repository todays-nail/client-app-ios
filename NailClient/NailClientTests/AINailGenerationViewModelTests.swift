//
//  AINailGenerationViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct AINailGenerationViewModelTests {

    @Test
    func submitGeneration_사진누락시_에러메시지를설정한다() async {
        let service = MockAINailGenerationService()
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )
        viewModel.userPrompt = "봄 느낌으로 만들어줘"

        await viewModel.submitGeneration()

        #expect(viewModel.errorMessage == "손 사진과 레퍼런스 사진을 모두 선택해 주세요.")
        #expect(service.createJobCallCount == 0)
    }

    @Test
    func submitGeneration_업로드실패시_에러를노출한다() async {
        let service = MockAINailGenerationService()
        service.uploadShouldFail = true
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )
        viewModel.userPrompt = "레퍼런스 느낌 그대로"
        viewModel.setSelectedImagesForTesting(
            handData: Data([0x01, 0x02]),
            referenceData: Data([0x03, 0x04])
        )

        await viewModel.submitGeneration()

        #expect(viewModel.isSubmitting == false)
        #expect(viewModel.errorMessage?.contains("Signed upload failed") == true)
        #expect(service.createJobCallCount == 0)
    }

    @Test
    func pollJobStatus_completed상태면_결과이미지URL을저장한다() async {
        let service = MockAINailGenerationService()
        service.statusResponses = [
            NailGenJobStatusResponse(status: .queued, resultImageURL: nil, errorCode: nil, errorMessage: nil),
            NailGenJobStatusResponse(status: .processing, resultImageURL: nil, errorCode: nil, errorMessage: nil),
            NailGenJobStatusResponse(status: .completed, resultImageURL: "https://example.com/result.png", errorCode: nil, errorMessage: nil),
        ]

        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )

        await viewModel.pollJobStatus(jobId: UUID())

        #expect(viewModel.isSubmitting == false)
        #expect(viewModel.statusMessage == "생성 완료")
        #expect(viewModel.resultImageURL?.absoluteString == "https://example.com/result.png")
    }
}

@MainActor
private final class MockAINailGenerationService: AINailGenerationServicing {
    var uploadShouldFail: Bool = false
    var statusResponses: [NailGenJobStatusResponse] = []
    var createJobCallCount: Int = 0

    func issueNailGenerationUploadURL(
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> NailGenUploadURLResponse {
        NailGenUploadURLResponse(
            bucket: "nail-inputs-private",
            jobId: jobId ?? UUID(),
            objectPath: "00000000-0000-4000-8000-000000000000/11111111-1111-4111-8111-111111111111/\(kind == .hand ? "hand" : "reference_1").jpg",
            signedUploadURL: "https://example.com/upload",
            expiresInSec: 600
        )
    }

    func uploadImageToSignedURL(
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        if uploadShouldFail {
            throw EdgeAPIError(statusCode: 500, message: "Signed upload failed", errorId: "TEST")
        }
    }

    func createNailGenerationJob(
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> NailGenCreateJobResponse {
        createJobCallCount += 1
        return NailGenCreateJobResponse(
            jobId: UUID(),
            status: .queued,
            pollAfterMs: 2000
        )
    }

    func getNailGenerationJobStatus(jobId: UUID) async throws -> NailGenJobStatusResponse {
        if statusResponses.isEmpty {
            return NailGenJobStatusResponse(
                status: .completed,
                resultImageURL: "https://example.com/result.png",
                errorCode: nil,
                errorMessage: nil
            )
        }
        return statusResponses.removeFirst()
    }
}
