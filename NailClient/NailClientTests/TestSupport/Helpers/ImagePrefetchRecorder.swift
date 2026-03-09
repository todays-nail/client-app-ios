import CoreGraphics
import Foundation
@testable import NailClient

@MainActor
final class ImagePrefetchRecorder {
    struct Call {
        let urls: [URL]
        let targetSize: CGSize?
        let resizeMode: NailImageResizeMode
        let destination: NailImagePrefetchDestination
    }

    private(set) var calls: [Call] = []

    var prefetch: NailImagePrefetchClosure {
        { [weak self] urls, targetSize, resizeMode, destination in
            self?.calls.append(
                Call(
                    urls: urls,
                    targetSize: targetSize,
                    resizeMode: resizeMode,
                    destination: destination
                )
            )
        }
    }

    func reset() {
        calls.removeAll()
    }
}
