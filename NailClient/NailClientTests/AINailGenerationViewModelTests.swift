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
    func canSubmit_사진두장선택시_프롬프트없이도참이다() async {
        let service = MockAINailGenerationService()
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )
        viewModel.setSelectedImagesForTesting(
            handData: Data([0x01, 0x02]),
            referenceData: Data([0x03, 0x04])
        )

        #expect(viewModel.canSubmit == true)
    }

    @Test
    func submitGeneration_프롬프트없어도_요청을진행한다() async {
        let service = MockAINailGenerationService()
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )
        viewModel.setSelectedImagesForTesting(
            handData: Data([0x01, 0x02]),
            referenceData: Data([0x03, 0x04])
        )

        await viewModel.submitGeneration()

        #expect(service.createJobCallCount == 1)
        #expect(service.lastCreateJobPrompt == "")
    }

    @Test
    func updatePrompt_50자를초과하면_잘라낸다() {
        let viewModel = AINailGenerationViewModel()
        let longPrompt = String(repeating: "a", count: 70)

        viewModel.updatePrompt(longPrompt)

        #expect(viewModel.userPrompt.count == AINailGenerationViewModel.maxPromptLength)
    }

    @Test
    func togglePromptTag_삽입후재탭하면_제거된다() {
        let viewModel = AINailGenerationViewModel()
        let tag = viewModel.quickPromptTags[0]

        viewModel.togglePromptTag(tag)
        #expect(viewModel.userPrompt.contains(tag))
        #expect(viewModel.selectedPromptTags.contains(tag))

        viewModel.togglePromptTag(tag)
        #expect(viewModel.userPrompt.contains(tag) == false)
        #expect(viewModel.selectedPromptTags.contains(tag) == false)
    }

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

    @Test
    func submitGeneration_pollAfterMs를_폴링간격에_반영한다() async {
        let service = MockAINailGenerationService()
        service.createJobPollAfterMs = 250
        service.statusResponses = [
            NailGenJobStatusResponse(status: .queued, resultImageURL: nil, errorCode: nil, errorMessage: nil),
            NailGenJobStatusResponse(status: .completed, resultImageURL: "https://example.com/result.png", errorCode: nil, errorMessage: nil),
        ]
        let recorder = PollIntervalRecorder()
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .seconds(2),
            maxPollingDuration: .seconds(1),
            sleepFn: { duration in
                await recorder.append(duration)
            }
        )
        viewModel.setSelectedImagesForTesting(
            handData: Data([0x01, 0x02]),
            referenceData: Data([0x03, 0x04])
        )

        await viewModel.submitGeneration()

        let recorded = await recorder.firstValue()
        #expect(recorded == .milliseconds(250))
    }
}

@MainActor
private final class MockAINailGenerationService: AINailGenerationServicing {
    var uploadShouldFail: Bool = false
    var statusResponses: [NailGenJobStatusResponse] = []
    var createJobCallCount: Int = 0
    var lastCreateJobPrompt: String?
    var createJobPollAfterMs: Int = 2000

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
        lastCreateJobPrompt = userPrompt
        return NailGenCreateJobResponse(
            jobId: UUID(),
            status: .queued,
            pollAfterMs: createJobPollAfterMs
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

private actor PollIntervalRecorder {
    private var values: [Duration] = []

    func append(_ value: Duration) {
        values.append(value)
    }

    func firstValue() -> Duration? {
        values.first
    }
}
