import Foundation
import CoreGraphics
import Nuke

enum NailImageResizeMode {
    case fill
    case fit

    var nukeContentMode: ImageProcessingOptions.ContentMode {
        switch self {
        case .fill:
            return .aspectFill
        case .fit:
            return .aspectFit
        }
    }

    var shouldCrop: Bool {
        switch self {
        case .fill:
            return true
        case .fit:
            return false
        }
    }
}

enum NailImagePipeline {
    private static let memoryCacheLimitBytes = 64 * 1024 * 1024
    private static let diskCacheLimitBytes = 512 * 1024 * 1024

    private static let urlCache: URLCache = {
        URLCache(
            memoryCapacity: memoryCacheLimitBytes,
            diskCapacity: diskCacheLimitBytes,
            diskPath: "com.todaysnail.urlcache"
        )
    }()

    static let shared: ImagePipeline = {
        var configuration = ImagePipeline.Configuration()

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.urlCache = urlCache
        sessionConfiguration.requestCachePolicy = .useProtocolCachePolicy
        sessionConfiguration.timeoutIntervalForRequest = 20
        sessionConfiguration.timeoutIntervalForResource = 60
        configuration.dataLoader = DataLoader(configuration: sessionConfiguration)

        let imageCache = ImageCache()
        imageCache.costLimit = memoryCacheLimitBytes
        configuration.imageCache = imageCache

        if let dataCache = try? DataCache(name: "com.todaysnail.nuke.datacache") {
            dataCache.sizeLimit = diskCacheLimitBytes
            configuration.dataCache = dataCache
        }

        configuration.isProgressiveDecodingEnabled = false
        configuration.isStoringPreviewsInMemoryCache = true

        return ImagePipeline(configuration: configuration)
    }()

    private static let prefetcher = ImagePrefetcher(pipeline: shared, destination: .diskCache)

    static func makeRequest(
        url: URL?,
        targetSize: CGSize? = nil,
        resizeMode: NailImageResizeMode = .fill
    ) -> ImageRequest? {
        guard let url else { return nil }

        var processors: [any ImageProcessing] = []
        if let targetSize,
           targetSize.width > 0,
           targetSize.height > 0 {
            processors.append(
                ImageProcessors.Resize(
                    size: targetSize,
                    unit: .points,
                    contentMode: resizeMode.nukeContentMode,
                    crop: resizeMode.shouldCrop,
                    upscale: false
                )
            )
        }

        return ImageRequest(url: url, processors: processors, priority: .normal)
    }

    static func prefetch(
        urls: [URL],
        targetSize: CGSize? = nil,
        resizeMode: NailImageResizeMode = .fill
    ) {
        let requests = urls.compactMap {
            makeRequest(url: $0, targetSize: targetSize, resizeMode: resizeMode)
        }
        guard !requests.isEmpty else { return }
        prefetcher.startPrefetching(with: requests)
    }
}
