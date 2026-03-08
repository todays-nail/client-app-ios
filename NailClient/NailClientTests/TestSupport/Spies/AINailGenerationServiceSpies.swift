import Foundation
@testable import NailClient

@MainActor
final class PushOpenAINailGenerationServiceSpy: AINailGenerationServicing {
    private let statusResponse: NailGenJobStatusResponse
    private(set) var statusCallCount: Int = 0

    init(statusResponse: NailGenJobStatusResponse) {
        self.statusResponse = statusResponse
    }

    func issueNailGenerationUploadURL(
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> NailGenUploadURLResponse {
        _ = kind
        _ = ext
        _ = contentType
        _ = bytes
        return NailGenerationTestFixtures.makeUploadURLResponse(jobId: jobId)
    }

    func uploadImageToSignedURL(
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        _ = signedUploadURL
        _ = contentType
        _ = imageData
    }

    func createNailGenerationJob(
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> NailGenCreateJobResponse {
        _ = shape
        _ = extensionMode
        _ = handObjectPath
        _ = referenceObjectPath
        return NailGenerationTestFixtures.makeCreateJobResponse()
    }

    func getNailGenerationJobStatus(jobId: UUID) async throws -> NailGenJobStatusResponse {
        _ = jobId
        statusCallCount += 1
        return statusResponse
    }
}

@MainActor
final class MockAINailGenerationService: AINailGenerationServicing {
    var uploadError: Error?
    var statusResponses: [NailGenJobStatusResponse] = []
    var statusError: Error?
    var createJobCallCount: Int = 0
    var statusCallCount: Int = 0
    var lastCreateJobExtensionMode: NailGenExtensionMode?
    var createJobPollAfterMs: Int = 2000

    func issueNailGenerationUploadURL(
        kind: NailGenUploadKind,
        ext: String,
        contentType: String,
        bytes: Int,
        jobId: UUID?
    ) async throws -> NailGenUploadURLResponse {
        _ = kind
        _ = ext
        _ = contentType
        _ = bytes
        return NailGenerationTestFixtures.makeUploadURLResponse(jobId: jobId)
    }

    func uploadImageToSignedURL(
        signedUploadURL: String,
        contentType: String,
        imageData: Data
    ) async throws {
        _ = signedUploadURL
        _ = contentType
        _ = imageData
        if let uploadError {
            throw uploadError
        }
    }

    func createNailGenerationJob(
        shape: NailGenShape,
        extensionMode: NailGenExtensionMode,
        handObjectPath: String,
        referenceObjectPath: String
    ) async throws -> NailGenCreateJobResponse {
        _ = shape
        _ = handObjectPath
        _ = referenceObjectPath
        createJobCallCount += 1
        lastCreateJobExtensionMode = extensionMode
        return NailGenerationTestFixtures.makeCreateJobResponse(pollAfterMs: createJobPollAfterMs)
    }

    func getNailGenerationJobStatus(jobId: UUID) async throws -> NailGenJobStatusResponse {
        _ = jobId
        statusCallCount += 1
        if let statusError {
            throw statusError
        }
        if statusResponses.isEmpty {
            return NailGenerationTestFixtures.makeStatusResponse(
                status: .completed,
                resultImageURL: "https://example.com/result.png"
            )
        }
        return statusResponses.removeFirst()
    }
}
