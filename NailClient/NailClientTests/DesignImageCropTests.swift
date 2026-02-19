#if false
//
//  DesignImageCropTests.swift
//  NailClientTests
//

import Foundation
import UIKit
import Testing
@testable import NailClient

@MainActor
struct DesignImageCropTests {
    @Test
    func normalizedImageData_반환_성공() {
        let source = testImage(size: CGSize(width: 80, height: 50), color: .systemTeal)
        let data = source.normalizedImageData()

        #expect(data != nil)
        #expect(!(data?.isEmpty ?? true))
    }

    @Test
    func imageByCropping_표시영역좌표기준_정상크롭() {
        let source = testImage(size: CGSize(width: 200, height: 200), color: .systemGreen)
        let displayedRect = CGRect(x: 20, y: 40, width: 120, height: 120)
        let normalizedRect = CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.5)

        let cropped = source.imageByCropping(
            to: normalizedRect,
            inDisplayedRect: displayedRect,
            viewTransformScale: 1,
            viewTranslation: .zero,
            targetScale: source.scale
        )

        #expect(cropped != nil)
        #expect(cropped?.size.width == 100)
        #expect(cropped?.size.height == 100)
    }

    @Test
    func imageByCropping_경계클램프_정상동작() {
        let source = testImage(size: CGSize(width: 100, height: 100), color: .systemRed)
        let displayedRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let normalizedRect = CGRect(x: -0.2, y: 0, width: 1.4, height: 1.0)

        let cropped = source.imageByCropping(
            to: normalizedRect,
            inDisplayedRect: displayedRect,
            viewTransformScale: 1,
            viewTranslation: .zero,
            targetScale: source.scale
        )

        #expect(cropped != nil)
        #expect(cropped?.size == CGSize(width: 100, height: 100))
    }

    @Test
    func imageByCropping_너무작은영역은_nil을반환() {
        let source = testImage(size: CGSize(width: 200, height: 120), color: .systemOrange)
        let displayedRect = CGRect(x: 0, y: 0, width: 200, height: 120)
        let normalizedRect = CGRect(x: 0.5, y: 0.5, width: 0.00001, height: 0.00001)

        let cropped = source.imageByCropping(
            to: normalizedRect,
            inDisplayedRect: displayedRect,
            viewTransformScale: 1,
            viewTranslation: .zero,
            targetScale: source.scale
        )

        #expect(cropped == nil)
    }
}

private func testImage(size: CGSize, color: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

#endif
