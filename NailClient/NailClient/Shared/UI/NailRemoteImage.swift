import SwiftUI
import NukeUI

enum NailRemoteImagePhase {
    case empty
    case success(Image)
    case failure
}

struct NailRemoteImage<Content: View>: View {
    let url: URL?
    let targetSize: CGSize?
    let resizeMode: NailImageResizeMode
    @ViewBuilder private var content: (NailRemoteImagePhase) -> Content

    init(
        url: URL?,
        targetSize: CGSize? = nil,
        resizeMode: NailImageResizeMode = .fill,
        @ViewBuilder content: @escaping (NailRemoteImagePhase) -> Content
    ) {
        self.url = url
        self.targetSize = targetSize
        self.resizeMode = resizeMode
        self.content = content
    }

    var body: some View {
        if let request = NailImagePipeline.makeRequest(
            url: url,
            targetSize: targetSize,
            resizeMode: resizeMode
        ) {
            LazyImage(request: request, transaction: .init(animation: nil)) { state in
                if let image = state.image {
                    content(.success(image))
                } else if state.error != nil {
                    content(.failure)
                } else {
                    content(.empty)
                }
            }
            .pipeline(NailImagePipeline.shared)
        } else {
            content(.failure)
        }
    }
}
