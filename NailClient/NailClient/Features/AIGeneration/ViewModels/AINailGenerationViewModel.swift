//
//  AINailGenerationViewModel.swift
//  NailClient
//

import Foundation
import Combine
import SwiftUI
import PhotosUI
import UIKit

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

    @Published var selectedShape: AINailShape = .almond
    @Published var userPrompt: String = ""
    @Published var selectedHandPhotoItem: PhotosPickerItem?
    @Published var selectedReferencePhotoItem: PhotosPickerItem?
    @Published private(set) var selectedPromptTags: Set<String> = []

    @Published private(set) var handImageData: Data?
    @Published private(set) var referenceImageData: Data?
    @Published private(set) var isSubmitting: Bool = false
    @Published private(set) var statusMessage: String = "손 사진과 네일 레퍼런스 사진을 선택해 주세요."
    @Published private(set) var resultImageURL: URL?
    @Published private(set) var currentJobId: UUID?
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
        maxPollingDuration: Duration = .seconds(90),
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
            errorMessage = "레퍼런스 사진을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    func submitGeneration() async {
        guard let service else {
            errorMessage = "세션이 준비되지 않았습니다. 다시 로그인해 주세요."
            return
        }
        guard let handImageData, let referenceImageData else {
            errorMessage = "손 사진과 레퍼런스 사진을 모두 선택해 주세요."
            return
        }

        errorMessage = nil
        resultImageURL = nil
        currentJobId = nil
        isSubmitting = true
        statusMessage = "이미지 업로드 준비 중..."

        do {
            let handUpload = try await service.issueNailGenerationUploadURL(
                kind: .hand,
                ext: "jpg",
                contentType: "image/jpeg",
                bytes: handImageData.count,
                jobId: nil
            )
            statusMessage = "손 사진 업로드 중..."
            try await service.uploadImageToSignedURL(
                signedUploadURL: handUpload.signedUploadURL,
                contentType: "image/jpeg",
                imageData: handImageData
            )

            let referenceUpload = try await service.issueNailGenerationUploadURL(
                kind: .reference,
                ext: "jpg",
                contentType: "image/jpeg",
                bytes: referenceImageData.count,
                jobId: handUpload.jobId
            )
            statusMessage = "레퍼런스 사진 업로드 중..."
            try await service.uploadImageToSignedURL(
                signedUploadURL: referenceUpload.signedUploadURL,
                contentType: "image/jpeg",
                imageData: referenceImageData
            )

            let job = try await service.createNailGenerationJob(
                shape: selectedShape.apiValue,
                userPrompt: trimmedPrompt,
                handObjectPath: handUpload.objectPath,
                referenceObjectPath: referenceUpload.objectPath
            )

            currentJobId = job.jobId
            statusMessage = "AI 생성 요청 완료. 결과를 확인하는 중..."
            await pollJobStatus(jobId: job.jobId)
        } catch {
            isSubmitting = false
            statusMessage = "요청 실패"
            errorMessage = error.localizedDescription
        }
    }

    func pollJobStatus(jobId: UUID) async {
        guard let service else {
            isSubmitting = false
            errorMessage = "세션이 준비되지 않았습니다."
            return
        }

        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            let clock = ContinuousClock()
            let startedAt = clock.now

            while !Task.isCancelled {
                do {
                    let response = try await service.getNailGenerationJobStatus(jobId: jobId)
                    switch response.status {
                    case .queued:
                        self.statusMessage = "생성 대기 중..."
                    case .processing:
                        self.statusMessage = "이미지 생성 중..."
                    case .completed:
                        self.isSubmitting = false
                        self.statusMessage = "생성 완료"
                        if let raw = response.resultImageURL, let url = URL(string: raw) {
                            self.resultImageURL = url
                        } else {
                            self.errorMessage = "결과 이미지 URL을 확인할 수 없습니다."
                        }
                        return
                    case .failed:
                        self.isSubmitting = false
                        self.statusMessage = "생성 실패"
                        self.errorMessage = response.errorMessage ?? response.errorCode ?? "알 수 없는 에러"
                        return
                    case .unknown:
                        self.isSubmitting = false
                        self.statusMessage = "생성 실패"
                        self.errorMessage = "알 수 없는 작업 상태입니다."
                        return
                    }
                } catch {
                    self.isSubmitting = false
                    self.statusMessage = "상태 조회 실패"
                    self.errorMessage = error.localizedDescription
                    return
                }

                if startedAt.duration(to: clock.now) >= self.maxPollingDuration {
                    self.isSubmitting = false
                    self.statusMessage = "시간 초과"
                    self.errorMessage = "생성 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요."
                    return
                }

                await self.sleepFn(self.pollInterval)
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
}
