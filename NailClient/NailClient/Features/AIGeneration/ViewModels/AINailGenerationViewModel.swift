//
//  AINailGenerationViewModel.swift
//  NailClient
//

import Foundation
import Combine
import SwiftUI
import PhotosUI
import UIKit
import OSLog

@MainActor
protocol AINailGenerationServicing: AnyObject {
    func issueNailGenerationUploadURL(
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> NailGenUploadURLResponse
    func uploadImageToSignedURL(
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws
    func createNailGenerationJob(
        shape: NailGenShape,
        userPrompt: String,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> NailGenCreateJobResponse
    func getNailGenerationJobStatus(jobId: UUID) async throws -> NailGenJobStatusResponse
}

#if DEBUG
extension AINailGenerationViewModel {
    static func previewState(
        selectedShape: AINailShape = .almond,
        selectedExtensionOption: AINailExtensionOption = .natural,
        promptSummary: String = "",
        resultImageURL: URL? = nil,
        currentJobId: UUID? = UUID(),
        canRefine: Bool = false,
        parentJobId: UUID? = nil,
        refinementTurn: Int = 0,
        isSubmitting: Bool = false,
        statusMessage: String = "생성 완료",
        errorMessage: String? = nil
    ) -> AINailGenerationViewModel {
        let viewModel = AINailGenerationViewModel()
        viewModel.selectedShape = selectedShape
        viewModel.selectedExtensionOption = selectedExtensionOption
        viewModel.latestPromptSummary = promptSummary
        viewModel.resultImageURL = resultImageURL
        viewModel.currentJobId = currentJobId
        viewModel.canRefine = canRefine
        viewModel.parentJobId = parentJobId
        viewModel.refinementTurn = refinementTurn
        viewModel.isSubmitting = isSubmitting
        viewModel.statusMessage = statusMessage
        viewModel.errorMessage = errorMessage
        return viewModel
    }
}
#endif

extension AppViewModel: AINailGenerationServicing {}

enum AINailShape: String, CaseIterable, Identifiable, Sendable {
    case almond
    case square
    case round

    var id: String { rawValue }

    var title: String {
        switch self {
        case .almond:
            return "아몬드"
        case .square:
            return "스퀘어"
        case .round:
            return "라운드"
        }
    }

    var apiValue: NailGenShape {
        switch self {
        case .almond:
            return .almond
        case .square:
            return .square
        case .round:
            return .round
        }
    }
}

enum AINailExtensionOption: String, CaseIterable, Identifiable, Sendable {
    case natural = "EXT_MODE=NATURAL"
    case extend = "EXT_MODE=EXTEND"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural:
            return "미연장"
        case .extend:
            return "연장"
        }
    }

    var apiToken: String { rawValue }

    var summaryText: String { "연장 옵션: \(title)" }
}

@MainActor
final class AINailGenerationViewModel: ObservableObject {
    enum ExternalJobOpenOutcome: Equatable {
        case opened
        case inProgress(message: String)
        case failed(message: String)
    }

    private static let uploadFailureMessage: String = "사진 업로드 중 문제가 발생했습니다. 네트워크 상태를 확인하고 다시 시도해 주세요."
    private static let prepareFailureMessage: String = "생성 요청 준비 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요."
    private static let createJobFailureMessage: String = "AI 생성 요청 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요."
    private static let generationFailureMessage: String = "AI 이미지 생성에 실패했습니다. 잠시 후 다시 시도해 주세요."
    private static let pollingFailureMessage: String = "생성 상태 확인 중 네트워크 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."
    private static let refinementDisabledMessage: String = "재수정 기능이 비활성화되었습니다."
    private static let timeoutFailureMessage: String = "생성 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요."

    @Published var selectedShape: AINailShape = .almond
    @Published var selectedExtensionOption: AINailExtensionOption = .natural
    @Published var selectedHandPhotoItem: PhotosPickerItem?
    @Published var selectedReferencePhotoItem: PhotosPickerItem?

    @Published private(set) var handImageData: Data?
    @Published private(set) var referenceImageData: Data?
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var statusMessage: String = "손 사진과 네일 디자인 사진을 선택해 주세요."
    @Published private(set) var resultImageURL: URL?
    @Published private(set) var currentJobId: UUID?
    @Published private(set) var canRefine: Bool = false
    @Published private(set) var parentJobId: UUID?
    @Published private(set) var refinementTurn: Int = 0
    @Published private(set) var latestPromptSummary: String = ""
    @Published var errorMessage: String?

    var onLifecycleEvent: ((AIGenerationLifecycleEvent) -> Void)?

    private weak var service: (any AINailGenerationServicing)?
    private var pollTask: Task<Void, Never>?

    private let pollInterval: Duration
    private let maxPollingDuration: Duration
    private let sleepFn: @Sendable (Duration) async -> Void

    init(
        service: (any AINailGenerationServicing)? = nil,
        pollInterval: Duration = .seconds(2),
        maxPollingDuration: Duration = .seconds(300),
        sleepFn: @escaping @Sendable (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        }
    ) {
        self.service = service
        self.pollInterval = pollInterval
        self.maxPollingDuration = maxPollingDuration
        self.sleepFn = sleepFn
    }

    deinit {
        pollTask?.cancel()
    }

    var canSubmit: Bool {
        !isSubmitting
            && handImageData != nil
            && referenceImageData != nil
    }

    var handPreviewImage: UIImage? {
        guard let handImageData else { return nil }
        return UIImage(data: handImageData)
    }

    var referencePreviewImage: UIImage? {
        guard let referenceImageData else { return nil }
        return UIImage(data: referenceImageData)
    }

    var hasReferenceImage: Bool {
        referenceImageData != nil
    }

    func bind(service: any AINailGenerationServicing) {
        self.service = service
    }

    func loadHandPhoto() async {
        do {
            handImageData = try await loadImageData(from: selectedHandPhotoItem)
            errorMessage = nil
        } catch {
            handImageData = nil
            errorMessage = "손 사진을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    func loadReferencePhoto() async {
        do {
            referenceImageData = try await loadImageData(from: selectedReferencePhotoItem)
            errorMessage = nil
        } catch {
            referenceImageData = nil
            errorMessage = "디자인 사진을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    func applyCroppedReferencePhotoData(_ croppedData: Data) throws {
        let previous = referenceImageData
        do {
            referenceImageData = try normalizedJPEGData(from: croppedData)
            errorMessage = nil
        } catch {
            referenceImageData = previous
            throw error
        }
    }

    func clearReferenceImage() {
        referenceImageData = nil
        selectedReferencePhotoItem = nil
        errorMessage = nil
    }

    func applySelectedDesignPayload(_ payload: AIDesignSelectionPayload) async -> Bool {
        do {
            let imageData: Data
            switch payload.source {
            case .remoteURL(let raw):
                guard let url = URL(string: raw) else {
                    throw EdgeAPIError(statusCode: -1, message: "디자인 이미지 URL이 올바르지 않습니다.", errorId: nil)
                }
                imageData = try await loadImageData(fromRemoteURL: url)
            case .localAsset(let name):
                imageData = try loadImageData(fromAssetNamed: name)
            }

            referenceImageData = imageData
            selectedReferencePhotoItem = nil
            errorMessage = nil
            return true
        } catch {
            errorMessage = "선택한 디자인 이미지를 불러오지 못했습니다: \(error.localizedDescription)"
            return false
        }
    }

    func submitGeneration() async {
        let traceId = AppLog.makeErrorId()
        AppLog.api.info("\(AppLog.prefix(traceId, "AI")) submit_generation_start")

        guard let service else {
            errorMessage = "세션이 준비되지 않았습니다. 다시 로그인해 주세요."
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_generation_blocked missing_service")
            return
        }
        guard let handImageData, let referenceImageData else {
            errorMessage = "손 사진과 디자인 사진을 모두 선택해 주세요."
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_generation_blocked missing_images")
            return
        }

        errorMessage = nil
        resultImageURL = nil
        currentJobId = nil
        canRefine = false
        parentJobId = nil
        refinementTurn = 0
        latestPromptSummary = selectedExtensionOption.summaryText
        isSubmitting = true
        statusMessage = "이미지 업로드 준비 중..."
        emitLifecycleEvent(.started(jobId: nil))
        emitLifecycleEvent(.progress(message: statusMessage))

        var stage = "prepare"
        do {
            stage = "issue_hand_upload_url"
            AppLog.api.debug("\(AppLog.prefix(traceId, "AI")) stage=\(stage, privacy: .public)")
            let handUpload = try await service.issueNailGenerationUploadURL(
                kind: .hand,
                ext: "jpg",
                contentType: "image/jpeg",
                bytes: handImageData.count,
                jobId: nil
            )

            stage = "upload_hand_image"
            AppLog.api.debug("\(AppLog.prefix(traceId, "AI")) stage=\(stage, privacy: .public)")
            statusMessage = "손 사진 업로드 중..."
            emitLifecycleEvent(.progress(message: statusMessage))
            try await service.uploadImageToSignedURL(
                signedUploadURL: handUpload.signedUploadURL,
                contentType: "image/jpeg",
                imageData: handImageData
            )

            stage = "issue_reference_upload_url"
            AppLog.api.debug("\(AppLog.prefix(traceId, "AI")) stage=\(stage, privacy: .public)")
            let referenceUpload = try await service.issueNailGenerationUploadURL(
                kind: .reference,
                ext: "jpg",
                contentType: "image/jpeg",
                bytes: referenceImageData.count,
                jobId: handUpload.jobId
            )

            stage = "upload_reference_image"
            AppLog.api.debug("\(AppLog.prefix(traceId, "AI")) stage=\(stage, privacy: .public)")
            statusMessage = "디자인 사진 업로드 중..."
            emitLifecycleEvent(.progress(message: statusMessage))
            try await service.uploadImageToSignedURL(
                signedUploadURL: referenceUpload.signedUploadURL,
                contentType: "image/jpeg",
                imageData: referenceImageData
            )

            stage = "create_generation_job"
            AppLog.api.debug("\(AppLog.prefix(traceId, "AI")) stage=\(stage, privacy: .public)")
            let job = try await service.createNailGenerationJob(
                shape: selectedShape.apiValue,
                userPrompt: selectedExtensionOption.apiToken,
                handObjectPath: handUpload.objectPath,
                referenceObjectPath: referenceUpload.objectPath
            )

            currentJobId = job.jobId
            canRefine = false
            statusMessage = "AI 생성 요청 완료. 결과를 확인하는 중..."
            emitLifecycleEvent(.started(jobId: job.jobId))
            emitLifecycleEvent(.progress(message: statusMessage))
            let interval = Self.resolvePollInterval(milliseconds: job.pollAfterMs, fallback: pollInterval)
            AppLog.api.info("\(AppLog.prefix(traceId, "AI")) submit_generation_job_created job_id=\(job.jobId.uuidString, privacy: .public)")
            await pollJobStatus(jobId: job.jobId, pollInterval: interval, traceId: traceId)
        } catch {
            let redactedError = AppLog.truncate(AppLog.redact(String(describing: error)))
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_generation_failed stage=\(stage, privacy: .public) error=\(redactedError, privacy: .public)")
            isSubmitting = false
            statusMessage = "요청 실패"
            let failureMessage = Self.submissionFailureMessage(for: stage)
            errorMessage = failureMessage
            emitLifecycleEvent(.failed(jobId: currentJobId, message: failureMessage))
        }
    }

    func submitRefinement(
        sourceJobId: UUID,
        shape _: AINailShape,
        prompt _: String
    ) async -> Bool {
        let traceId = AppLog.makeErrorId()
        canRefine = false
        statusMessage = "요청 실패"
        errorMessage = Self.refinementDisabledMessage
        AppLog.api.info(
            "\(AppLog.prefix(traceId, "AI")) submit_refinement_blocked disabled source_job_id=\(sourceJobId.uuidString, privacy: .public)"
        )
        emitLifecycleEvent(.failed(jobId: sourceJobId, message: Self.refinementDisabledMessage))
        return false
    }

    func pollJobStatus(jobId: UUID, pollInterval: Duration? = nil, traceId: String? = nil) async {
        let logTraceId = traceId ?? AppLog.makeErrorId()
        guard let service else {
            isSubmitting = false
            errorMessage = "세션이 준비되지 않았습니다."
            AppLog.api.error("\(AppLog.prefix(logTraceId, "AI")) poll_blocked missing_service job_id=\(jobId.uuidString, privacy: .public)")
            return
        }

        let effectivePollInterval = pollInterval ?? self.pollInterval
        AppLog.api.info("\(AppLog.prefix(logTraceId, "AI")) poll_start job_id=\(jobId.uuidString, privacy: .public)")

        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            let clock = ContinuousClock()
            let startedAt = clock.now

            while !Task.isCancelled {
                do {
                    let response = try await service.getNailGenerationJobStatus(jobId: jobId)
                    self.parentJobId = response.parentJobId.flatMap(UUID.init(uuidString:))
                    self.refinementTurn = response.refinementTurn ?? 0
                    self.canRefine = false
                    switch response.status {
                    case .queued:
                        AppLog.api.debug("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=queued")
                        self.statusMessage = "생성 대기 중..."
                        self.emitLifecycleEvent(.progress(message: self.statusMessage))
                    case .processing:
                        AppLog.api.debug("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=processing")
                        self.statusMessage = "이미지 생성 중..."
                        self.emitLifecycleEvent(.progress(message: self.statusMessage))
                    case .completed:
                        AppLog.api.info("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=completed")
                        self.isSubmitting = false
                        self.statusMessage = "생성 완료"
                        let resultURL: URL?
                        if let raw = response.resultImageURL, let url = URL(string: raw) {
                            self.resultImageURL = url
                            resultURL = url
                        } else {
                            self.errorMessage = "결과 이미지 URL을 확인할 수 없습니다."
                            resultURL = nil
                        }
                        self.emitLifecycleEvent(.completed(jobId: jobId, resultImageURL: resultURL))
                        return
                    case .failed:
                        let errorCode = response.errorCode ?? "none"
                        let errorMessage = response.errorMessage ?? "none"
                        AppLog.api.error(
                            "\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=failed code=\(errorCode, privacy: .public) message=\(AppLog.truncate(AppLog.redact(errorMessage)), privacy: .public)"
                        )
                        self.isSubmitting = false
                        self.statusMessage = "생성 실패"
                        self.errorMessage = Self.generationFailureMessage
                        self.emitLifecycleEvent(.failed(jobId: jobId, message: Self.generationFailureMessage))
                        return
                    case .unknown:
                        AppLog.api.error("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=unknown")
                        self.isSubmitting = false
                        self.statusMessage = "생성 실패"
                        self.errorMessage = Self.generationFailureMessage
                        self.emitLifecycleEvent(.failed(jobId: jobId, message: Self.generationFailureMessage))
                        return
                    }
                } catch {
                    let redactedError = AppLog.truncate(AppLog.redact(String(describing: error)))
                    AppLog.api.error("\(AppLog.prefix(logTraceId, "AI")) poll_failed job_id=\(jobId.uuidString, privacy: .public) error=\(redactedError, privacy: .public)")
                    self.isSubmitting = false
                    self.statusMessage = "요청 실패"
                    self.errorMessage = Self.pollingFailureMessage
                    self.emitLifecycleEvent(.failed(jobId: jobId, message: Self.pollingFailureMessage))
                    return
                }

                if startedAt.duration(to: clock.now) >= self.maxPollingDuration {
                    AppLog.api.error("\(AppLog.prefix(logTraceId, "AI")) poll_timeout job_id=\(jobId.uuidString, privacy: .public)")
                    self.isSubmitting = false
                    self.statusMessage = "시간 초과"
                    self.errorMessage = Self.timeoutFailureMessage
                    self.emitLifecycleEvent(.failed(jobId: jobId, message: Self.timeoutFailureMessage))
                    return
                }

                await self.sleepFn(effectivePollInterval)
            }
        }

        await pollTask?.value
    }

    func openResultFromPush(jobId: UUID) async -> ExternalJobOpenOutcome {
        guard let service else {
            let message = "세션이 준비되지 않았습니다. 다시 로그인해 주세요."
            statusMessage = "요청 실패"
            errorMessage = message
            return .failed(message: message)
        }

        do {
            let response = try await service.getNailGenerationJobStatus(jobId: jobId)
            isSubmitting = false
            currentJobId = jobId
            parentJobId = response.parentJobId.flatMap(UUID.init(uuidString:))
            refinementTurn = response.refinementTurn ?? 0
            canRefine = false

            switch response.status {
            case .completed:
                guard let rawURL = response.resultImageURL,
                      let resultURL = URL(string: rawURL)
                else {
                    let message = "결과 이미지 URL을 확인할 수 없습니다."
                    statusMessage = "생성 실패"
                    errorMessage = message
                    return .failed(message: message)
                }

                resultImageURL = resultURL
                statusMessage = "생성 완료"
                errorMessage = nil
                return .opened
            case .failed:
                let message = response.errorMessage?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let resolved = (message?.isEmpty == false) ? message! : Self.generationFailureMessage
                statusMessage = "생성 실패"
                errorMessage = resolved
                return .failed(message: resolved)
            case .queued:
                let message = "생성 대기 중입니다. 잠시 후 다시 확인해 주세요."
                statusMessage = message
                errorMessage = nil
                return .inProgress(message: message)
            case .processing:
                let message = "이미지 생성 중입니다. 잠시 후 다시 확인해 주세요."
                statusMessage = message
                errorMessage = nil
                return .inProgress(message: message)
            case .unknown:
                statusMessage = "생성 실패"
                errorMessage = Self.generationFailureMessage
                return .failed(message: Self.generationFailureMessage)
            }
        } catch {
            statusMessage = "요청 실패"
            errorMessage = Self.pollingFailureMessage
            return .failed(message: Self.pollingFailureMessage)
        }
    }

    func setSelectedImagesForTesting(handData: Data?, referenceData: Data?) {
        handImageData = handData
        referenceImageData = referenceData
    }

    private func loadImageData(from item: PhotosPickerItem?) async throws -> Data? {
        guard let item else { return nil }
        guard let originalData = try await item.loadTransferable(type: Data.self) else {
            throw EdgeAPIError(statusCode: -1, message: "이미지 데이터를 읽을 수 없습니다.", errorId: nil)
        }
        return try normalizedJPEGData(from: originalData)
    }

    private func loadImageData(fromRemoteURL url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw EdgeAPIError(statusCode: -1, message: "디자인 이미지를 가져오지 못했습니다.", errorId: nil)
        }
        return try normalizedJPEGData(from: data)
    }

    private func loadImageData(fromAssetNamed name: String) throws -> Data {
        guard let image = UIImage(named: name),
              let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw EdgeAPIError(statusCode: -1, message: "디자인 에셋을 읽을 수 없습니다.", errorId: nil)
        }
        return jpegData
    }

    private func normalizedJPEGData(from originalData: Data) throws -> Data {
        guard let image = UIImage(data: originalData),
              let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw EdgeAPIError(statusCode: -1, message: "이미지 변환에 실패했습니다.", errorId: nil)
        }
        return jpegData
    }

    private static func resolvePollInterval(milliseconds: Int, fallback: Duration) -> Duration {
        guard milliseconds > 0 else { return fallback }
        return .milliseconds(milliseconds)
    }

    private func emitLifecycleEvent(_ event: AIGenerationLifecycleEvent) {
        onLifecycleEvent?(event)
    }

    private static func submissionFailureMessage(for stage: String) -> String {
        switch stage {
        case "issue_hand_upload_url", "upload_hand_image", "issue_reference_upload_url", "upload_reference_image":
            return uploadFailureMessage
        case "create_generation_job":
            return createJobFailureMessage
        default:
            return prepareFailureMessage
        }
    }
}
