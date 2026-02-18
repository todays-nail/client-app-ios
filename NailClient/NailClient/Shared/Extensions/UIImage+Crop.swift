//
//  UIImage+Crop.swift
//  NailClient
//

import CoreGraphics
import UIKit

extension UIImage {
    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func normalizedImageData(
        compressionQuality: CGFloat = 0.92
    ) -> Data? {
        normalizedImage().jpegData(compressionQuality: compressionQuality)
    }

    func imageByCropping(
        to normalizedRect: CGRect,
        inDisplayedRect displayedRect: CGRect,
        viewTransformScale: CGFloat,
        viewTranslation: CGSize,
        targetScale: CGFloat
    ) -> UIImage? {
        guard displayedRect.width > 0, displayedRect.height > 0 else { return nil }
        let transformScale = max(viewTransformScale, 0.01)
        guard targetScale > 0 else { return nil }

        let normalizedCrop = normalizedRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard normalizedCrop.width > 0.001, normalizedCrop.height > 0.001 else { return nil }

        let normalizedSourceImage = normalizedImage()
        guard let normalizedCGImage = normalizedSourceImage.cgImage else { return nil }

        let baseWidth = CGFloat(normalizedCGImage.width)
        let baseHeight = CGFloat(normalizedCGImage.height)
        let transformedImageSize = CGSize(
            width: displayedRect.width * transformScale,
            height: displayedRect.height * transformScale
        )
        let transformedImageCenter = CGPoint(
            x: displayedRect.midX + viewTranslation.width,
            y: displayedRect.midY + viewTranslation.height
        )
        let transformedImageOrigin = CGPoint(
            x: transformedImageCenter.x - transformedImageSize.width / 2,
            y: transformedImageCenter.y - transformedImageSize.height / 2
        )

        let cropInContainer = CGRect(
            x: displayedRect.minX + normalizedCrop.minX * displayedRect.width,
            y: displayedRect.minY + normalizedCrop.minY * displayedRect.height,
            width: normalizedCrop.width * displayedRect.width,
            height: normalizedCrop.height * displayedRect.height
        )

        let sourceToContainerScaleX = baseWidth / transformedImageSize.width
        let sourceToContainerScaleY = baseHeight / transformedImageSize.height

        var sourceRect = CGRect(
            x: (cropInContainer.minX - transformedImageOrigin.x) * sourceToContainerScaleX,
            y: (cropInContainer.minY - transformedImageOrigin.y) * sourceToContainerScaleY,
            width: cropInContainer.width * sourceToContainerScaleX,
            height: cropInContainer.height * sourceToContainerScaleY
        )

        sourceRect = CGRect(
            x: sourceRect.minX,
            y: sourceRect.minY,
            width: sourceRect.width,
            height: sourceRect.height
        )
        sourceRect = sourceRect.intersection(CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight))
        guard sourceRect.width > 1, sourceRect.height > 1 else { return nil }

        let cropPixelRect = CGRect(
            x: sourceRect.origin.x,
            y: sourceRect.origin.y,
            width: sourceRect.width,
            height: sourceRect.height
        )
        guard let cropped = normalizedCGImage.cropping(to: cropPixelRect) else { return nil }

        return UIImage(cgImage: cropped, scale: targetScale, orientation: .up)
    }
}
