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
    func refineNailGenerationJob(
        sourceJobId: UUID,
        shape: NailGenShape,
        userPrompt: String
    ) async throws -> NailGenRefineJobResponse
    func getNailGenerationJobStatus(jobId: UUID) async throws -> NailGenJobStatusResponse
}

#if DEBUG
extension AINailGenerationViewModel {
    static func previewState(
        selectedShape: AINailShape = .almond,
        promptSummary: String = "",
        resultImageURL: URL? = nil,
        currentJobId: UUID? = UUID(),
        canRefine: Bool = true,
        parentJobId: UUID? = nil,
        refinementTurn: Int = 0,
        isSubmitting: Bool = false,
        statusMessage: String = "생성 완료",
        errorMessage: String? = nil
    ) -> AINailGenerationViewModel {
        let viewModel = AINailGenerationViewModel()
        viewModel.selectedShape = selectedShape
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

@MainActor
final class AINailGenerationViewModel: ObservableObject {
    static let maxPromptLength: Int = 50
    static let maxRefinementPromptLength: Int = 500
    private static let requestFailureMessage: String = "네트워크가 일시적으로 불안정합니다. 잠시 후 다시 시도해 주세요."

    @Published var selectedShape: AINailShape = .almond
    @Published var userPrompt: String = ""
    @Published var selectedHandPhotoItem: PhotosPickerItem?
    @Published var selectedReferencePhotoItem: PhotosPickerItem?
    @Published private(set) var selectedPromptTags: Set<String> = []

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

    private weak var service: (any AINailGenerationServicing)?
    private var pollTask: Task<Void, Never>?

    private let pollInterval: Duration
    private let maxPollingDuration: Duration
    private let sleepFn: @Sendable (Duration) async -> Void

    let quickPromptTags: [String] = [
        "#화려하게",
        "#심플하게",
        "#파츠추가",
        "#계절무드",
        "#웨딩네일",
        "#데일리무드",
    ]

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

    func updatePrompt(_ prompt: String) {
        let normalized = String(prompt.prefix(Self.maxPromptLength))
        userPrompt = normalized
        syncSelectedPromptTags()
    }

    func togglePromptTag(_ tag: String) {
        guard quickPromptTags.contains(tag) else { return }

        if selectedPromptTags.contains(tag) || userPrompt.contains(tag) {
            removePromptTag(tag)
        } else {
            appendPromptTag(tag)
        }
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
        latestPromptSummary = trimmedPrompt
        isSubmitting = true
        statusMessage = "이미지 업로드 준비 중..."

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
            try await service.uploadImageToSignedURL(
                signedUploadURL: referenceUpload.signedUploadURL,
                contentType: "image/jpeg",
                imageData: referenceImageData
            )

            stage = "create_generation_job"
            AppLog.api.debug("\(AppLog.prefix(traceId, "AI")) stage=\(stage, privacy: .public)")
            let job = try await service.createNailGenerationJob(
                shape: selectedShape.apiValue,
                userPrompt: trimmedPrompt,
                handObjectPath: handUpload.objectPath,
                referenceObjectPath: referenceUpload.objectPath
            )

            currentJobId = job.jobId
            canRefine = false
            statusMessage = "AI 생성 요청 완료. 결과를 확인하는 중..."
            let interval = Self.resolvePollInterval(milliseconds: job.pollAfterMs, fallback: pollInterval)
            AppLog.api.info("\(AppLog.prefix(traceId, "AI")) submit_generation_job_created job_id=\(job.jobId.uuidString, privacy: .public)")
            await pollJobStatus(jobId: job.jobId, pollInterval: interval, traceId: traceId)
        } catch {
            let redactedError = AppLog.truncate(AppLog.redact(String(describing: error)))
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_generation_failed stage=\(stage, privacy: .public) error=\(redactedError, privacy: .public)")
            isSubmitting = false
            statusMessage = "요청 실패"
            errorMessage = Self.requestFailureMessage
        }
    }

    func submitRefinement(
        sourceJobId: UUID,
        shape: AINailShape,
        prompt: String
    ) async -> Bool {
        let traceId = AppLog.makeErrorId()
        AppLog.api.info("\(AppLog.prefix(traceId, "AI")) submit_refinement_start source_job_id=\(sourceJobId.uuidString, privacy: .public)")

        guard let service else {
            errorMessage = "세션이 준비되지 않았습니다. 다시 로그인해 주세요."
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_refinement_blocked missing_service")
            return false
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "수정 요청 프롬프트를 입력해 주세요."
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_refinement_blocked empty_prompt")
            return false
        }
        guard trimmed.count <= Self.maxRefinementPromptLength else {
            errorMessage = "수정 요청 프롬프트는 최대 \(Self.maxRefinementPromptLength)자까지 입력할 수 있습니다."
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_refinement_blocked prompt_too_long")
            return false
        }

        errorMessage = nil
        isSubmitting = true
        canRefine = false
        statusMessage = "수정 요청 중..."

        do {
            latestPromptSummary = trimmed
            let job = try await service.refineNailGenerationJob(
                sourceJobId: sourceJobId,
                shape: shape.apiValue,
                userPrompt: trimmed
            )
            selectedShape = shape
            currentJobId = job.jobId
            refinementTurn = 1
            statusMessage = "수정 생성 요청 완료. 결과를 확인하는 중..."

            let interval = Self.resolvePollInterval(milliseconds: job.pollAfterMs, fallback: pollInterval)
            AppLog.api.info(
                "\(AppLog.prefix(traceId, "AI")) submit_refinement_job_created source_job_id=\(sourceJobId.uuidString, privacy: .public) job_id=\(job.jobId.uuidString, privacy: .public)"
            )
            await pollJobStatus(jobId: job.jobId, pollInterval: interval, traceId: traceId)
            return errorMessage == nil && statusMessage == "생성 완료"
        } catch {
            let redactedError = AppLog.truncate(AppLog.redact(String(describing: error)))
            AppLog.api.error("\(AppLog.prefix(traceId, "AI")) submit_refinement_failed error=\(redactedError, privacy: .public)")
            isSubmitting = false
            statusMessage = "요청 실패"
            errorMessage = Self.requestFailureMessage
            return false
        }
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
                    self.canRefine = response.canRefine ?? false
                    switch response.status {
                    case .queued:
                        AppLog.api.debug("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=queued")
                        self.statusMessage = "생성 대기 중..."
                    case .processing:
                        AppLog.api.debug("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=processing")
                        self.statusMessage = "이미지 생성 중..."
                    case .completed:
                        AppLog.api.info("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=completed")
                        self.isSubmitting = false
                        self.statusMessage = "생성 완료"
                        if let raw = response.resultImageURL, let url = URL(string: raw) {
                            self.resultImageURL = url
                        } else {
                            self.errorMessage = "결과 이미지 URL을 확인할 수 없습니다."
                        }
                        return
                    case .failed:
                        let errorCode = response.errorCode ?? "none"
                        let errorMessage = response.errorMessage ?? "none"
                        AppLog.api.error(
                            "\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=failed code=\(errorCode, privacy: .public) message=\(AppLog.truncate(AppLog.redact(errorMessage)), privacy: .public)"
                        )
                        self.isSubmitting = false
                        self.statusMessage = "생성 실패"
                        self.errorMessage = Self.requestFailureMessage
                        return
                    case .unknown:
                        AppLog.api.error("\(AppLog.prefix(logTraceId, "AI")) poll_status job_id=\(jobId.uuidString, privacy: .public) status=unknown")
                        self.isSubmitting = false
                        self.statusMessage = "생성 실패"
                        self.errorMessage = Self.requestFailureMessage
                        return
                    }
                } catch {
                    let redactedError = AppLog.truncate(AppLog.redact(String(describing: error)))
                    AppLog.api.error("\(AppLog.prefix(logTraceId, "AI")) poll_failed job_id=\(jobId.uuidString, privacy: .public) error=\(redactedError, privacy: .public)")
                    self.isSubmitting = false
                    self.statusMessage = "요청 실패"
                    self.errorMessage = Self.requestFailureMessage
                    return
                }

                if startedAt.duration(to: clock.now) >= self.maxPollingDuration {
                    AppLog.api.error("\(AppLog.prefix(logTraceId, "AI")) poll_timeout job_id=\(jobId.uuidString, privacy: .public)")
                    self.isSubmitting = false
                    self.statusMessage = "시간 초과"
                    self.errorMessage = "생성 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요."
                    return
                }

                await self.sleepFn(effectivePollInterval)
            }
        }

        await pollTask?.value
    }

    func setSelectedImagesForTesting(handData: Data?, referenceData: Data?) {
        handImageData = handData
        referenceImageData = referenceData
    }

    private var trimmedPrompt: String {
        userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func appendPromptTag(_ tag: String) {
        let current = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextPrompt: String
        if current.isEmpty {
            nextPrompt = tag
        } else if current.contains(tag) {
            nextPrompt = current
        } else {
            nextPrompt = "\(current) \(tag)"
        }
        updatePrompt(nextPrompt)
    }

    private func removePromptTag(_ tag: String) {
        let withoutTag = userPrompt.replacingOccurrences(of: tag, with: "")
        updatePrompt(normalizeWhitespace(in: withoutTag))
    }

    private func syncSelectedPromptTags() {
        selectedPromptTags = Set(quickPromptTags.filter { userPrompt.contains($0) })
    }

    private func normalizeWhitespace(in text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func resolvePollInterval(milliseconds: Int, fallback: Duration) -> Duration {
        guard milliseconds > 0 else { return fallback }
        return .milliseconds(milliseconds)
    }
}
