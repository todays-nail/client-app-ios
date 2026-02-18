//
//  DesignImageCropperView.swift
//  NailClient
//

import SwiftUI
import UIKit

struct DesignImageCropperView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onApply: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cropRect: CGRect = CGRect(x: 0.12, y: 0.2, width: 0.76, height: 0.56)
    @State private var imageScale: CGFloat = 1
    @State private var imageTranslation: CGSize = .zero
    @State private var lastImageScale: CGFloat = 1
    @State private var lastImageTranslation: CGSize = .zero
    @State private var isInitializingCropRect: Bool = false
    @State private var baselineCropRect: CGRect = .zero
    @State private var applyErrorMessage: String?
    @State private var isApplying: Bool = false

    @State private var imageContainerSize: CGSize = .zero
    @State private var imageDisplayedRect: CGRect = .zero
    @State private var lastCropRect: CGRect = .zero

    private enum CropHandle: CaseIterable {
        case topLeft
        case top
        case topRight
        case leading
        case trailing
        case bottomLeft
        case bottom
        case bottomRight
    }

    private enum Axis {
        case x
        case y
    }

    private let handleSize: CGFloat = 26
    private let handleCornerRadius: CGFloat = 13
    private let minCropSide: CGFloat = 70

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 12)
                HStack {
                    Text("디자인 이미지 크롭")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text("원하는 영역을 잡고 확인해 주세요.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

                GeometryReader { geometry in
                    let containerSize = geometry.size
                    let displayedRect = fittedImageRect(for: sourceImage.size, in: containerSize)
                    Color.clear
                        .onAppear {
                            imageContainerSize = containerSize
                            imageDisplayedRect = displayedRect
                            if !isInitializingCropRect {
                                let initialWidth = min(containerSize.width * 0.76, containerSize.height * 0.58)
                                let initialHeight = min(containerSize.height * 0.58, containerSize.width * 0.76)
                                let width = max(initialWidth, minCropSide)
                                let height = max(initialHeight, minCropSide)
                                cropRect = CGRect(
                                    x: (containerSize.width - width) / 2,
                                    y: (containerSize.height - height) / 2,
                                    width: width,
                                    height: height
                                )
                                isInitializingCropRect = true
                                baselineCropRect = cropRect
                                lastCropRect = cropRect
                            }
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            imageContainerSize = newSize
                            imageDisplayedRect = fittedImageRect(for: sourceImage.size, in: newSize)
                            clampCropRect()
                        }
                        .overlay(alignment: .center) {
                            ZStack {
                                Image(uiImage: sourceImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: containerSize.width, height: containerSize.height)
                                    .scaleEffect(imageScale)
                                    .offset(imageTranslation)
                                    .clipped()
                                    .highPriorityGesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let nextOffset = CGSize(
                                                    width: lastImageTranslation.width + value.translation.width,
                                                    height: lastImageTranslation.height + value.translation.height
                                                )
                                                imageTranslation = clampImageOffset(
                                                    nextOffset,
                                                    in: containerSize,
                                                    displayedRect: displayedRect
                                                )
                                            }
                                            .onEnded { _ in
                                                lastImageTranslation = imageTranslation
                                            }
                                    )
                                    .simultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                imageScale = max(1, min(lastImageScale * value, 4))
                                                imageScale = max(1, imageScale)
                                                imageTranslation = clampImageOffset(
                                                    imageTranslation,
                                                    in: containerSize,
                                                    displayedRect: displayedRect
                                                )
                                                lastImageTranslation = imageTranslation
                                            }
                                            .onEnded { _ in
                                                imageScale = max(1, min(imageScale, 4))
                                                lastImageScale = imageScale
                                                imageTranslation = clampImageOffset(
                                                    imageTranslation,
                                                    in: containerSize,
                                                    displayedRect: displayedRect
                                                )
                                                lastImageTranslation = imageTranslation
                                            }
                                    )

                                cropDimLayer

                                Group {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Color.white, lineWidth: 1.5)
                                        .frame(width: cropRect.width, height: cropRect.height)
                                        .position(
                                            x: cropRect.midX,
                                            y: cropRect.midY
                                        )
                                        .contentShape(Rectangle())
                                        .gesture(cropMoveGesture())

                                    ForEach(CropHandle.allCases, id: \.self) { handle in
                                        handleView(for: handle)
                                            .position(handlePosition(for: handle))
                                            .gesture(cropResizeGesture(handle: handle))
                                    }
                                }
                            }
                            .frame(width: containerSize.width, height: containerSize.height)
                            .onAppear {
                                applyErrorMessage = nil
                            }
                        }
                }

                if let applyErrorMessage {
                    Text(applyErrorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.top, 10)
                }

                HStack(spacing: 12) {
                    Button("취소") {
                        dismiss()
                        onCancel()
                    }
                    .buttonStyle(.bordered)

                    Button("적용") {
                        applyCrop()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isApplying)
                }
                .padding(.top, 14)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)
        }
    }

    private func cropMoveGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                if lastCropRect == .zero {
                    lastCropRect = cropRect
                }
                let translated = CGRect(
                    x: lastCropRect.minX + value.translation.width,
                    y: lastCropRect.minY + value.translation.height,
                    width: lastCropRect.width,
                    height: lastCropRect.height
                )
                cropRect = clampRect(translated)
            }
            .onEnded { _ in
                lastCropRect = cropRect
            }
    }

    private func cropResizeGesture(handle: CropHandle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if baselineCropRect == .zero {
                    baselineCropRect = cropRect
                }
                var next = baselineCropRect

                switch handle {
                case .top:
                    next.origin.y += value.translation.height
                    next.size.height -= value.translation.height
                case .bottom:
                    next.size.height += value.translation.height
                case .leading:
                    next.origin.x += value.translation.width
                    next.size.width -= value.translation.width
                case .trailing:
                    next.size.width += value.translation.width
                case .topLeft:
                    next.origin.x += value.translation.width
                    next.size.width -= value.translation.width
                    next.origin.y += value.translation.height
                    next.size.height -= value.translation.height
                case .topRight:
                    next.size.width += value.translation.width
                    next.origin.y += value.translation.height
                    next.size.height -= value.translation.height
                case .bottomLeft:
                    next.origin.x += value.translation.width
                    next.size.width -= value.translation.width
                    next.size.height += value.translation.height
                case .bottomRight:
                    next.size.width += value.translation.width
                    next.size.height += value.translation.height
                }
                cropRect = clampRect(next)
            }
            .onEnded { _ in
                baselineCropRect = cropRect
            }
    }

    private func handleView(for handle: CropHandle) -> some View {
        Circle()
            .fill(.white)
            .frame(width: handleSize, height: handleSize)
            .overlay {
                Circle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            }
    }

    private var cropDimLayer: some View {
        Color.clear
            .overlay {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .mask(
                        CropMaskShape(rect: cropRect, cornerRadius: 4)
                            .fill(style: FillStyle(eoFill: true))
                            .foregroundStyle(.black)
                    )
            }
    }

    private func handlePosition(for handle: CropHandle) -> CGPoint {
        switch handle {
        case .topLeft:
            CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .top:
            CGPoint(x: cropRect.midX, y: cropRect.minY)
            - CGPoint(x: 0, y: 13)
            + CGPoint(x: handleSize / 4, y: 0)
        case .topRight:
            CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .leading:
            CGPoint(x: cropRect.minX, y: cropRect.midY)
            - CGPoint(x: 13, y: 0)
            + CGPoint(x: 0, y: handleSize / 4)
        case .trailing:
            CGPoint(x: cropRect.maxX, y: cropRect.midY)
            + CGPoint(x: 13, y: 0)
            + CGPoint(x: 0, y: handleSize / 4)
        case .bottomLeft:
            CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottom:
            CGPoint(x: cropRect.midX, y: cropRect.maxY)
            + CGPoint(x: 0, y: 13)
            + CGPoint(x: handleSize / 4, y: 0)
        case .bottomRight:
            CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    private func applyCrop() {
        guard imageContainerSize.width > 0, imageDisplayedRect.width > 0 else {
            applyErrorMessage = "영역이 너무 작습니다. 조금 더 크게 선택해 주세요."
            return
        }
        let normalized = CGRect(
            x: clamp01((cropRect.minX - 0) / imageContainerSize.width),
            y: clamp01((cropRect.minY - 0) / imageContainerSize.height),
            width: clamp01(cropRect.width / imageContainerSize.width),
            height: clamp01(cropRect.height / imageContainerSize.height)
        )

        guard normalized.width >= 0.03, normalized.height >= 0.03 else {
            applyErrorMessage = "영역이 너무 작습니다. 조금 더 크게 선택해 주세요."
            return
        }

        let cropped = sourceImage.imageByCropping(
            to: normalized,
            inDisplayedRect: imageDisplayedRect,
            viewTransformScale: imageScale,
            viewTranslation: imageTranslation,
            targetScale: sourceImage.scale
        )

        guard let cropped, let croppedData = cropped.normalizedImageData() else {
            applyErrorMessage = "영역이 너무 작습니다. 조금 더 크게 선택해 주세요."
            return
        }

        isApplying = true
        Task {
            onApply(croppedData)
            isApplying = false
        }
    }

    private func clampRect(_ rect: CGRect) -> CGRect {
        var next = rect
        next.size.width = max(minCropSide, next.size.width)
        next.size.height = max(minCropSide, next.size.height)

        if next.minX < 0 {
            next.size.width = max(minCropSide, next.size.width + next.minX)
            next.origin.x = 0
        }
        if next.minY < 0 {
            next.size.height = max(minCropSide, next.size.height + next.minY)
            next.origin.y = 0
        }
        if next.maxX > imageContainerSize.width {
            next.size.width = max(minCropSide, imageContainerSize.width - next.minX)
            next.origin.x = min(next.origin.x, imageContainerSize.width - next.size.width)
        }
        if next.maxY > imageContainerSize.height {
            next.size.height = max(minCropSide, imageContainerSize.height - next.minY)
            next.origin.y = min(next.origin.y, imageContainerSize.height - next.size.height)
        }

        if next.size.width <= 0 || next.size.height <= 0 {
            return CGRect(x: (imageContainerSize.width - minCropSide) / 2, y: (imageContainerSize.height - minCropSide) / 2, width: minCropSide, height: minCropSide)
        }

        return next
    }

    private func clampCropRect() {
        cropRect = clampRect(cropRect)
    }

    private func fittedImageRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        let widthRatio = containerSize.width / max(imageSize.width, 1)
        let heightRatio = containerSize.height / max(imageSize.height, 1)
        let scale = min(widthRatio, heightRatio)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = (containerSize.width - fittedSize.width) / 2
        let y = (containerSize.height - fittedSize.height) / 2
        return CGRect(x: x, y: y, width: fittedSize.width, height: fittedSize.height)
    }

    private func clampImageOffset(_ offset: CGSize, in containerSize: CGSize, displayedRect: CGRect) -> CGSize {
        let scaled = CGSize(
            width: displayedRect.width * imageScale,
            height: displayedRect.height * imageScale
        )
        let halfRangeX = max(0, (scaled.width - containerSize.width) / 2)
        let halfRangeY = max(0, (scaled.height - containerSize.height) / 2)
        return CGSize(
            width: min(max(offset.width, -halfRangeX), halfRangeX),
            height: min(max(offset.height, -halfRangeY), halfRangeY)
        )
    }

    private func clamp01(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }
}

private struct CropMaskShape: Shape {
    let rect: CGRect
    let cornerRadius: CGFloat

    func path(in bounds: CGRect) -> Path {
        var path = Path()
        path.addRect(bounds)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}

private extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}
