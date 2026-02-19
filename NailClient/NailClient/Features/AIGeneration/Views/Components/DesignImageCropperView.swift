//
//  DesignImageCropperView.swift
//  NailClient
//

import CropViewController
import SwiftUI
import UIKit

struct DesignImageCropperView: UIViewControllerRepresentable {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onApply: (Data) -> Void

    func makeUIViewController(context: Context) -> CropViewController {
        let controller = CropViewController(image: sourceImage)
        controller.delegate = context.coordinator
        controller.title = "디자인 이미지 크롭"
        controller.doneButtonTitle = "적용"
        controller.cancelButtonTitle = "취소"

        // Basic crop flow only: keep drag/zoom + rectangular crop.
        controller.rotateButtonsHidden = true
        controller.rotateClockwiseButtonHidden = true
        controller.resetButtonHidden = true
        controller.aspectRatioPickerButtonHidden = true

        return controller
    }

    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel, onApply: onApply)
    }

    final class Coordinator: NSObject, CropViewControllerDelegate {
        private let onCancel: () -> Void
        private let onApply: (Data) -> Void

        init(onCancel: @escaping () -> Void, onApply: @escaping (Data) -> Void) {
            self.onCancel = onCancel
            self.onApply = onApply
        }

        func cropViewController(
            _ cropViewController: CropViewController,
            didCropToImage image: UIImage,
            withRect cropRect: CGRect,
            angle: Int
        ) {
            if let data = image.jpegData(compressionQuality: 0.92) ?? image.pngData() {
                onApply(data)
                return
            }
            onCancel()
        }

        func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
            onCancel()
        }
    }
}
