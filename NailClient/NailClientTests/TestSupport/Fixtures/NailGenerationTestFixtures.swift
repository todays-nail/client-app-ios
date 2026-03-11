import Foundation
@testable import NailClient

enum NailGenerationTestFixtures {
    static func makeUploadURLResponse(jobId: UUID? = nil) -> NailGenUploadURLResponse {
        NailGenUploadURLResponse(
            bucket: "nail-inputs-private",
            jobId: jobId ?? UUID(),
            objectPath: "00000000-0000-4000-8000-000000000000/11111111-1111-4111-8111-111111111111/hand.jpg",
            signedUploadURL: "https://example.com/upload",
            publicObjectURL: nil,
            expiresInSec: 600
        )
    }

    static func makeCreateJobResponse(
        jobId: UUID = UUID(),
        pollAfterMs: Int = 2000
    ) -> NailGenCreateJobResponse {
        NailGenCreateJobResponse(
            jobId: jobId,
            status: .queued,
            pollAfterMs: pollAfterMs
        )
    }

    static func makeStatusResponse(
        status: NailGenJobStatus,
        resultImageURL: String? = nil,
        handImageURL: String? = nil,
        referenceImageURL: String? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        parentJobId: String? = nil,
        refinementTurn: Int? = nil,
        canRefine: Bool? = nil,
        shape: String? = nil,
        extensionMode: NailGenExtensionMode? = nil,
        isLiked: Bool? = nil
    ) -> NailGenJobStatusResponse {
        NailGenJobStatusResponse(
            status: status,
            resultImageURL: resultImageURL,
            handImageURL: handImageURL,
            referenceImageURL: referenceImageURL,
            shape: shape,
            extensionMode: extensionMode,
            errorCode: errorCode,
            errorMessage: errorMessage,
            parentJobId: parentJobId,
            refinementTurn: refinementTurn,
            isLiked: isLiked,
            canRefine: canRefine
        )
    }

    static func makeListItem(
        jobId: UUID,
        parentJobId: UUID?,
        refinementTurn: Int,
        resultImageURL: String? = nil,
        thumbnailImageURL: String? = nil,
        shape: String = "almond",
        extensionMode: NailGenExtensionMode? = .natural,
        isLiked: Bool = false
    ) -> NailGenListItemResponse {
        NailGenListItemResponse(
            jobId: jobId,
            resultImageURL: resultImageURL ?? "https://example.com/\(jobId.uuidString).jpg",
            thumbnailImageURL: thumbnailImageURL,
            shape: shape,
            extensionMode: extensionMode,
            createdAt: Date(),
            parentJobId: parentJobId,
            refinementTurn: refinementTurn,
            isLiked: isLiked
        )
    }
}
