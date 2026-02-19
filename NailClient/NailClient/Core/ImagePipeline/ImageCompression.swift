import Foundation
import UIKit
import ImageIO

enum ImageCompressionError: LocalizedError {
    case invalidImageData
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "이미지 데이터를 읽을 수 없습니다."
        case .encodeFailed:
            return "이미지 변환에 실패했습니다."
        }
    }
}

enum ImageCompression {
    static let defaultMaxPixel: CGFloat = 1536
    static let defaultJPEGQuality: CGFloat = 0.82

    static func normalizedJPEGData(
        from originalData: Data,
        maxPixel: CGFloat = defaultMaxPixel,
        quality: CGFloat = defaultJPEGQuality
    ) throws -> Data {
        guard let source = CGImageSourceCreateWithData(originalData as CFData, nil) else {
            throw ImageCompressionError.invalidImageData
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageCompressionError.invalidImageData
        }

        let image = UIImage(cgImage: cgImage)
        guard let jpegData = image.jpegData(compressionQuality: quality) else {
            throw ImageCompressionError.encodeFailed
        }
        return jpegData
    }

    static func normalizedJPEGData(
        from image: UIImage,
        maxPixel: CGFloat = defaultMaxPixel,
        quality: CGFloat = defaultJPEGQuality
    ) throws -> Data {
        let longestSide = max(image.size.width, image.size.height)
        if longestSide <= 0 {
            throw ImageCompressionError.invalidImageData
        }

        let downscaleRatio = min(1, maxPixel / longestSide)
        let targetSize = CGSize(
            width: max(1, image.size.width * downscaleRatio),
            height: max(1, image.size.height * downscaleRatio)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpegData = scaledImage.jpegData(compressionQuality: quality) else {
            throw ImageCompressionError.encodeFailed
        }
        return jpegData
    }
}
