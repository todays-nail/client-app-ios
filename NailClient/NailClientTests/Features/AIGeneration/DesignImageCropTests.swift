//
//  DesignImageCropTests.swift
//  NailClientTests
//

import CropViewController
import UIKit
import Testing
@testable import NailClient

@MainActor
struct DesignImageCropTests {
    @Test
    func coordinator_취소시_onCancel을호출한다() {
        let sourceImage = testImage(size: CGSize(width: 80, height: 50), color: .systemTeal)
        var cancelCallCount = 0
        var appliedData: Data?

        let subject = DesignImageCropperView(
            sourceImage: sourceImage,
            title: "디자인 크롭",
            cropAspectRatio: CGSize(width: 4, height: 5),
            isAspectRatioLocked: true,
            isResetAspectRatioEnabled: false,
            onCancel: { cancelCallCount += 1 },
            onApply: { appliedData = $0 }
        )
        let coordinator = subject.makeCoordinator()

        coordinator.cropViewController(
            CropViewController(image: sourceImage),
            didFinishCancelled: true
        )

        #expect(cancelCallCount == 1)
        #expect(appliedData == nil)
    }

    @Test
    func coordinator_크롭성공시_인코딩된이미지데이터를전달한다() throws {
        let sourceImage = testImage(size: CGSize(width: 120, height: 120), color: .systemGreen)
        var cancelCallCount = 0
        var appliedData: Data?

        let subject = DesignImageCropperView(
            sourceImage: sourceImage,
            title: "손 사진 크롭",
            cropAspectRatio: nil,
            isAspectRatioLocked: false,
            isResetAspectRatioEnabled: true,
            onCancel: { cancelCallCount += 1 },
            onApply: { appliedData = $0 }
        )
        let coordinator = subject.makeCoordinator()

        coordinator.cropViewController(
            CropViewController(image: sourceImage),
            didCropToImage: sourceImage,
            withRect: CGRect(x: 0, y: 0, width: 60, height: 60),
            angle: 0
        )

        let data = try #require(appliedData)
        #expect(UIImage(data: data) != nil)
        #expect(cancelCallCount == 0)
    }
}

private func testImage(size: CGSize, color: UIColor) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}
