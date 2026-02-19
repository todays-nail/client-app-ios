//
//  AINailGenerationResultView.swift
//  NailClient
//

import SwiftUI
#if DEBUG
import UIKit
#endif

struct AINailGenerationResultView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AINailGenerationViewModel
    private let previewResultUIImage: UIImage?

    init(
        viewModel: AINailGenerationViewModel,
        previewResultUIImage: UIImage? = nil
    ) {
        self.viewModel = viewModel
        self.previewResultUIImage = previewResultUIImage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                resultImageSection
                summarySection
                refineHintSection
            }
            .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(AIGenerationDesignTokens.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("생성 결과")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resultImageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 생성 결과")
                .font(.system(AIGenerationDesignTokens.sectionTitleStyle, weight: .bold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)

            if let previewResultUIImage {
                Image(uiImage: previewResultUIImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous)
                            .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                    )
            } else if let resultImageURL = viewModel.resultImageURL {
                AsyncImage(url: resultImageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28, weight: .semibold))
                            Text("결과 이미지를 불러오지 못했습니다.")
                                .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .medium))
                        }
                        .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 220)
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
            }

            if viewModel.isSubmitting {
                Text(viewModel.statusMessage)
                    .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard(title: "선택한 네일 모양", value: viewModel.selectedShape.title)
            summaryCard(title: "연장 옵션", value: extensionSummary)
        }
    }

    private var refineHintSection: some View {
        summaryCard(title: "재편집", value: "재수정 기능은 정책상 지원하지 않습니다.")
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.secondaryText)
            Text(value)
                .font(.system(AIGenerationDesignTokens.bodyStyle, weight: .medium))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AIGenerationDesignTokens.cardSubtleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
        )
    }

    private var bottomButton: some View {
        Button {
            dismiss()
        } label: {
            Text("생성 화면으로 돌아가기")
                .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AIGenerationDesignTokens.cardSubtleBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AIGenerationDesignTokens.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AIGenerationDesignTokens.border)
                .frame(height: 1)
        }
    }

    private var extensionSummary: String {
        let trimmed = viewModel.latestExtensionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "입력 없음" : trimmed
    }
}

#if DEBUG
private enum PreviewImageFactory {
    static func makeResultImage(size: CGSize = CGSize(width: 1080, height: 1350)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            let backgroundColors = [
                UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1).cgColor,
                UIColor(red: 0.92, green: 0.88, blue: 0.84, alpha: 1).cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: backgroundColors, locations: [0, 1]) else {
                cg.setFillColor(UIColor.systemGray6.cgColor)
                cg.fill(rect)
                return
            }
            cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

            let palmRect = CGRect(x: size.width * 0.18, y: size.height * 0.16, width: size.width * 0.64, height: size.height * 0.68)
            let palmPath = UIBezierPath(roundedRect: palmRect, cornerRadius: 120)
            UIColor(red: 0.96, green: 0.80, blue: 0.73, alpha: 1).setFill()
            palmPath.fill()

            let nailColor = UIColor(red: 0.88, green: 0.30, blue: 0.55, alpha: 1)
            let nailShadow = UIColor(red: 0.74, green: 0.17, blue: 0.40, alpha: 0.35)
            let nailSize = CGSize(width: 78, height: 122)
            let startX = palmRect.minX + 56
            let y = palmRect.minY + 64

            for index in 0..<5 {
                let x = startX + CGFloat(index) * 94
                let nailRect = CGRect(origin: CGPoint(x: x, y: y), size: nailSize)
                let nailPath = UIBezierPath(roundedRect: nailRect, cornerRadius: 20)
                nailShadow.setFill()
                nailPath.fill()

                let insetRect = nailRect.insetBy(dx: 4, dy: 4)
                UIBezierPath(roundedRect: insetRect, cornerRadius: 18).fill(with: .normal, alpha: 1)
                nailColor.setFill()
                UIBezierPath(roundedRect: insetRect, cornerRadius: 18).fill()
            }
        }
    }
}

#Preview("성공 · 정책 고정") {
    NavigationStack {
        AINailGenerationResultView(
            viewModel: .previewState(
                selectedShape: .square,
                selectedExtensionOption: .extend,
                extensionSummary: "연장 옵션: 연장",
                resultImageURL: nil,
                statusMessage: "생성 완료"
            ),
            previewResultUIImage: PreviewImageFactory.makeResultImage()
        )
    }
}

#Preview("로딩 · 처리 중") {
    NavigationStack {
        AINailGenerationResultView(
            viewModel: .previewState(
                selectedShape: .almond,
                selectedExtensionOption: .natural,
                extensionSummary: "연장 옵션: 미연장",
                resultImageURL: nil,
                isSubmitting: true,
                statusMessage: "AI가 이미지를 생성하고 있어요..."
            ),
            previewResultUIImage: PreviewImageFactory.makeResultImage()
        )
    }
}

#Preview("오류 · 안내 표시") {
    NavigationStack {
        AINailGenerationResultView(
            viewModel: .previewState(
                selectedShape: .round,
                selectedExtensionOption: .natural,
                extensionSummary: "연장 옵션: 미연장",
                resultImageURL: nil,
                statusMessage: "요청 실패",
                errorMessage: "네트워크가 일시적으로 불안정합니다. 잠시 후 다시 시도해 주세요."
            ),
            previewResultUIImage: PreviewImageFactory.makeResultImage()
        )
    }
}
#endif
