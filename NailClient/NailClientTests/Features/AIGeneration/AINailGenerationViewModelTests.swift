//
//  AINailGenerationViewModelTests.swift
//  NailClientTests
//

import Foundation
import UIKit
import Testing
@testable import NailClient

@MainActor
struct AINailGenerationViewModelTests {

    @Test
    func canSubmit_사진두장선택시_참이다() async {
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
    func submitGeneration_기본연장옵션은_미연장토큰으로전송한다() async {
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
        #expect(service.lastCreateJobExtensionMode == .natural)
        #expect(viewModel.latestExtensionSummary == "연장 옵션: 미연장")
    }

    @Test
    func submitGeneration_연장옵션선택시_연장토큰으로전송한다() async {
        let service = MockAINailGenerationService()
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )
        viewModel.selectedExtensionOption = .extend
        viewModel.setSelectedImagesForTesting(
            handData: Data([0x01, 0x02]),
            referenceData: Data([0x03, 0x04])
        )

        await viewModel.submitGeneration()

        #expect(service.createJobCallCount == 1)
        #expect(service.lastCreateJobExtensionMode == .extend)
        #expect(viewModel.latestExtensionSummary == "연장 옵션: 연장")
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

        await viewModel.submitGeneration()

        #expect(viewModel.errorMessage == "손 사진과 디자인 사진을 모두 선택해 주세요.")
        #expect(service.createJobCallCount == 0)
    }

    @Test
    func submitGeneration_업로드실패시_에러를노출한다() async {
        let service = MockAINailGenerationService()
        service.uploadError = EdgeAPIError(statusCode: 500, message: "Signed upload failed", errorId: "TEST")
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

        #expect(viewModel.isSubmitting == false)
        #expect(viewModel.errorMessage == "사진 업로드 중 문제가 발생했습니다. 네트워크 상태를 확인하고 다시 시도해 주세요.")
        #expect(service.createJobCallCount == 0)
    }

    @Test
    func submitGeneration_타임아웃시_요청실패안내를노출한다() async {
        let service = MockAINailGenerationService()
        service.uploadError = URLError(.timedOut)
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

        #expect(viewModel.statusMessage == "요청 실패")
        #expect(viewModel.errorMessage == "사진 업로드 중 문제가 발생했습니다. 네트워크 상태를 확인하고 다시 시도해 주세요.")
    }

    @Test
    func pollJobStatus_completed상태면_결과이미지URL을저장하고_canRefine은항상false다() async {
        let service = MockAINailGenerationService()
        service.statusResponses = [
            NailGenerationTestFixtures.makeStatusResponse(status: .queued),
            NailGenerationTestFixtures.makeStatusResponse(status: .processing),
            NailGenerationTestFixtures.makeStatusResponse(
                status: .completed,
                resultImageURL: "https://example.com/result.png",
                canRefine: true
            ),
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
        #expect(viewModel.canRefine == false)
    }

    @Test
    func submitGeneration_pollAfterMs를_폴링간격에_반영한다() async {
        let service = MockAINailGenerationService()
        service.createJobPollAfterMs = 250
        service.statusResponses = [
            NailGenerationTestFixtures.makeStatusResponse(status: .queued),
            NailGenerationTestFixtures.makeStatusResponse(
                status: .completed,
                resultImageURL: "https://example.com/result.png"
            ),
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

    @Test
    func pollJobStatus_failed응답시_상세오류를노출하지않는다() async {
        let service = MockAINailGenerationService()
        service.statusResponses = [
            NailGenerationTestFixtures.makeStatusResponse(
                status: .failed,
                errorCode: "OPENAI_HTTP_ERROR",
                errorMessage: "openai status=500 body=internal"
            ),
        ]
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )

        await viewModel.pollJobStatus(jobId: UUID())

        #expect(viewModel.statusMessage == "생성 실패")
        #expect(viewModel.errorMessage == "AI 이미지 생성에 실패했습니다. 잠시 후 다시 시도해 주세요.")
    }

    @Test
    func submitGeneration_라이프사이클이벤트를전파한다() async {
        let service = MockAINailGenerationService()
        service.statusResponses = [
            NailGenerationTestFixtures.makeStatusResponse(status: .queued),
            NailGenerationTestFixtures.makeStatusResponse(
                status: .completed,
                resultImageURL: "https://example.com/result.png"
            ),
        ]

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

        var events: [AIGenerationLifecycleEvent] = []
        viewModel.onLifecycleEvent = { event in
            events.append(event)
        }

        await viewModel.submitGeneration()

        let hasStarted = events.contains(where: { event in
            if case .started = event { return true }
            return false
        })
        let hasProgress = events.contains(where: { event in
            if case .progress(let message) = event {
                return message == "디자인 사진 업로드 중..."
            }
            return false
        })
        let hasCompleted = events.contains(where: { event in
            if case .completed = event { return true }
            return false
        })

        #expect(hasStarted == true)
        #expect(hasProgress == true)
        #expect(hasCompleted == true)
    }

    @Test
    func submitRefinement_항상차단된다() async {
        let service = MockAINailGenerationService()
        let viewModel = AINailGenerationViewModel(
            service: service,
            pollInterval: .milliseconds(1),
            maxPollingDuration: .seconds(1),
            sleepFn: { _ in }
        )

        let succeeded = await viewModel.submitRefinement(
            sourceJobId: UUID(),
            shape: .almond
        )

        #expect(succeeded == false)
        #expect(viewModel.errorMessage == "재수정 기능이 비활성화되었습니다.")
        #expect(service.createJobCallCount == 0)
        #expect(service.statusCallCount == 0)
    }

    @Test
    func applyCroppedReferencePhotoData_유효한데이터_저장한다() throws {
        let viewModel = AINailGenerationViewModel()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60))
        let imageData = renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }.jpegData(compressionQuality: 0.92) ?? Data()

        try viewModel.applyCroppedReferencePhotoData(imageData)

        #expect(viewModel.referenceImageData != nil)
        #expect(viewModel.referencePreviewImage != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test
    func applyCroppedReferencePhotoData_적용후_제출가능_결정() throws {
        let viewModel = AINailGenerationViewModel()
        viewModel.setSelectedImagesForTesting(handData: Data([0x01, 0x02]), referenceData: nil)
        #expect(viewModel.canSubmit == false)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60))
        let imageData = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }.jpegData(compressionQuality: 0.92) ?? Data()

        try viewModel.applyCroppedReferencePhotoData(imageData)
        #expect(viewModel.canSubmit == true)
    }

    @Test
    func applyCroppedReferencePhotoData_잘못된데이터_예외발생및기존이미지보존() throws {
        let viewModel = AINailGenerationViewModel()
        let originalData = Data([0x01, 0x02, 0x03, 0x04])
        viewModel.setSelectedImagesForTesting(handData: Data([0xAA]), referenceData: originalData)

        do {
            try viewModel.applyCroppedReferencePhotoData(Data([0x00]))
            Issue.record("예외가 발생하지 않았습니다.")
        } catch {
            #expect(viewModel.referenceImageData == originalData)
            #expect(viewModel.canSubmit == true)
        }
    }

    @Test
    func applyCroppedHandPhotoData_유효한데이터_저장한다() throws {
        let viewModel = AINailGenerationViewModel()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60))
        let imageData = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }.jpegData(compressionQuality: 0.92) ?? Data()

        try viewModel.applyCroppedHandPhotoData(imageData)

        #expect(viewModel.handImageData != nil)
        #expect(viewModel.handPreviewImage != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.canSubmit == false)
    }

    @Test
    func applyCroppedHandPhotoData_적용후_제출가능_결정() throws {
        let viewModel = AINailGenerationViewModel()
        viewModel.setSelectedImagesForTesting(handData: nil, referenceData: Data([0x01, 0x02]))
        #expect(viewModel.canSubmit == false)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60))
        let imageData = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }.jpegData(compressionQuality: 0.92) ?? Data()

        try viewModel.applyCroppedHandPhotoData(imageData)
        #expect(viewModel.canSubmit == true)
    }

    @Test
    func applyCroppedHandPhotoData_잘못된데이터_예외발생및기존이미지보존() throws {
        let viewModel = AINailGenerationViewModel()
        let originalData = Data([0xAA, 0xBB, 0xCC, 0xDD])
        viewModel.setSelectedImagesForTesting(handData: originalData, referenceData: Data([0x11]))

        do {
            try viewModel.applyCroppedHandPhotoData(Data([0x00]))
            Issue.record("예외가 발생하지 않았습니다.")
        } catch {
            #expect(viewModel.handImageData == originalData)
            #expect(viewModel.canSubmit == true)
        }
    }
}
