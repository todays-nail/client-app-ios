//
//  AINailGenerationView.swift
//  NailClient
//

import PhotosUI
import SwiftUI
import UIKit

struct AINailGenerationView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = AINailGenerationViewModel()
    @State private var showResultView: Bool = false
    @State private var showDesignSourceDialog: Bool = false
    @State private var isDesignPhotoPickerPresented: Bool = false
    @State private var lastAppliedDesignPayloadID: UUID?
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AIGenerationDesignTokens.sectionSpacing) {
                noticeCard
                photoUploadSection
                nailShapeSection
                promptSection
                statusSection
            }
            .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .background(AIGenerationDesignTokens.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            submitButtonBar
        }
        .navigationTitle("AI 네일 생성")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResultView) {
            if viewModel.resultImageURL != nil {
                AINailGenerationResultView(viewModel: viewModel)
            } else {
                EmptyView()
            }
        }
        .onAppear {
            viewModel.bind(service: appViewModel)
            applySelectedDesignIfNeeded(requireAITab: false)
        }
        .onChange(of: viewModel.selectedHandPhotoItem) { _, _ in
            Task { await viewModel.loadHandPhoto() }
        }
        .onChange(of: viewModel.selectedReferencePhotoItem) { _, _ in
            Task { await viewModel.loadReferencePhoto() }
        }
        .onChange(of: appViewModel.selectedAIDesignPayload) { _, _ in
            applySelectedDesignIfNeeded(requireAITab: true)
        }
        .onChange(of: viewModel.resultImageURL) { _, resultImageURL in
            showResultView = resultImageURL != nil
        }
        .confirmationDialog("디자인 선택", isPresented: $showDesignSourceDialog, titleVisibility: .visible) {
            Button("피드에서 선택") {
                appViewModel.beginAIDesignSelectionFromFeed()
            }
            Button("사진 추가") {
                isDesignPhotoPickerPresented = true
            }
            Button("취소", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $isDesignPhotoPickerPresented,
            selection: $viewModel.selectedReferencePhotoItem,
            matching: .images
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    isPromptFocused = false
                }
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { isPromptFocused = false }
        )
        .scrollDismissesKeyboard(.interactively)
    }

    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(number: 1, title: "사진 업로드")

            HStack(spacing: 12) {
                handPhotoSelectionCard(
                    title: "나의 손",
                    selection: $viewModel.selectedHandPhotoItem,
                    image: viewModel.handPreviewImage,
                    placeholder: .handPhoto
                )
                designPhotoSelectionCard(
                    title: "디자인",
                    image: viewModel.referencePreviewImage,
                    placeholder: .designPhoto
                )
            }
        }
    }

    private var nailShapeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(number: 2, title: "네일 모양 선택")

            HStack(spacing: 12) {
                ForEach(AINailShape.allCases) { shape in
                    nailShapeCard(shape)
                }
            }
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(number: 3, title: "추가 요청 사항")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.quickPromptTags, id: \.self) { tag in
                        promptTagChip(tag)
                    }
                }
                .padding(.vertical, 1)
            }

            promptEditorCard
        }
    }

    @ViewBuilder
    private var statusSection: some View {
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

    private func sectionHeader(number: Int, title: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(AIGenerationDesignTokens.sectionBadgeStyle, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 32, height: 32)
                .background(AIGenerationDesignTokens.accent)
                .clipShape(Circle())

            Text(title)
                .font(.system(AIGenerationDesignTokens.sectionTitleStyle, weight: .bold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private func handPhotoSelectionCard(
        title: String,
        selection: Binding<PhotosPickerItem?>,
        image: UIImage?,
        placeholder: AIPromptPlaceholderStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(AIGenerationDesignTokens.fieldTitleStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)

            PhotosPicker(selection: selection, matching: .images) {
                photoSelectionCardContent(image: image, placeholder: placeholder)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func designPhotoSelectionCard(
        title: String,
        image: UIImage?,
        placeholder: AIPromptPlaceholderStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(AIGenerationDesignTokens.fieldTitleStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)

            Button {
                showDesignSourceDialog = true
            } label: {
                photoSelectionCardContent(image: image, placeholder: placeholder)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func photoSelectionCardContent(image: UIImage?, placeholder: AIPromptPlaceholderStyle) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous)
                .fill(AIGenerationDesignTokens.cardBackground)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                switch placeholder {
                case .handPhoto:
                    Image(systemName: "hand.raised")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(AIGenerationDesignTokens.placeholder)
                case .designPhoto:
                    NailDesignPlaceholderIcon()
                        .frame(width: 52, height: 52)
                        .foregroundStyle(AIGenerationDesignTokens.placeholder)
                }
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous)
                .stroke(
                    image == nil ? AIGenerationDesignTokens.dashedBorder : AIGenerationDesignTokens.border,
                    style: image == nil
                        ? StrokeStyle(lineWidth: 1, dash: [5, 4])
                        : StrokeStyle(lineWidth: 1)
                )
        )
    }

    private func nailShapeCard(_ shape: AINailShape) -> some View {
        let isSelected = viewModel.selectedShape == shape

        return Button {
            viewModel.selectedShape = shape
        } label: {
            VStack(spacing: 10) {
                shapePreview(shape)
                    .frame(height: 58)

                Text(shape.title)
                    .font(.system(AIGenerationDesignTokens.fieldTitleStyle, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? AIGenerationDesignTokens.accent : AIGenerationDesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? AIGenerationDesignTokens.cardBackground : AIGenerationDesignTokens.cardSubtleBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected ? AIGenerationDesignTokens.accent : AIGenerationDesignTokens.border, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(AIGenerationDesignTokens.accent)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shapePreview(_ shape: AINailShape) -> some View {
        switch shape {
        case .almond:
            AlmondNailPreviewShape()
                .fill(AIGenerationDesignTokens.shapeFill)
                .overlay(
                    AlmondNailPreviewShape()
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
                .frame(width: 40, height: 60)
        case .square:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AIGenerationDesignTokens.shapeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
                .frame(width: 42, height: 52)
        case .round:
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AIGenerationDesignTokens.shapeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
                .frame(width: 44, height: 54)
        }
    }

    private func promptTagChip(_ tag: String) -> some View {
        let isSelected = viewModel.selectedPromptTags.contains(tag)

        return Button {
            viewModel.togglePromptTag(tag)
        } label: {
            Text(tag)
                .font(.system(AIGenerationDesignTokens.chipStyle, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AIGenerationDesignTokens.chipUnselectedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AIGenerationDesignTokens.accent : AIGenerationDesignTokens.chipUnselectedBackground)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isSelected ? Color.clear : AIGenerationDesignTokens.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var promptEditorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if viewModel.userPrompt.isEmpty {
                    Text("원하시는 스타일을 자유롭게 적어주세요.\n예: 웨딩 촬영용으로 우아한 느낌을 원해요.")
                        .font(.system(AIGenerationDesignTokens.bodyStyle, weight: .medium))
                        .foregroundStyle(AIGenerationDesignTokens.placeholder)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }

                TextEditor(text: promptBinding)
                    .focused($isPromptFocused)
                    .submitLabel(.done)
                    .font(.system(AIGenerationDesignTokens.bodyStyle, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .onSubmit {
                        isPromptFocused = false
                    }
            }

            HStack {
                Spacer()
                Text("\(viewModel.userPrompt.count)/\(AINailGenerationViewModel.maxPromptLength)")
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AIGenerationDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
        )
    }

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.noticeTint)
                .padding(.top, 2)

            Text("AI가 손 모양과 디자인을 분석하여 최적의 디자인을 제안합니다. 실제 시술 환경에 따라 결과물에 미세한 차이가 발생할 수 있습니다.")
                .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .medium))
                .lineSpacing(3)
                .foregroundStyle(AIGenerationDesignTokens.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AIGenerationDesignTokens.cardSubtleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
        )
    }

    private var submitButtonBar: some View {
        Button {
            Task { await viewModel.submitGeneration() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(viewModel.isSubmitting ? "생성 중..." : "AI 네일 생성하기")
                    .font(.system(AIGenerationDesignTokens.ctaStyle, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(viewModel.canSubmit ? AIGenerationDesignTokens.accent : AIGenerationDesignTokens.placeholder)
            )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSubmit)
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

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.userPrompt },
            set: { viewModel.updatePrompt($0) }
        )
    }

    private func applySelectedDesignIfNeeded(requireAITab: Bool) {
        guard let payload = appViewModel.selectedAIDesignPayload else { return }
        if payload.id == lastAppliedDesignPayloadID { return }
        if requireAITab && appViewModel.selectedMainTab != .ai { return }

        Task {
            let applied = await viewModel.applySelectedDesignPayload(payload)
            if applied {
                await MainActor.run {
                    lastAppliedDesignPayloadID = payload.id
                }
            }
        }
    }

}

private struct DashedHandPlaceholderIcon: View {
    var body: some View {
        ZStack {
            HandOutlineShape()
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 4]))
            HandPalmCurveShape()
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 4]))
        }
    }
}

private enum AIPromptPlaceholderStyle {
    case handPhoto
    case designPhoto
}

private struct NailDesignPlaceholderIcon: View {
    private struct NailMarkSpec: Hashable {
        let x: CGFloat
        let y: CGFloat
        let widthScale: CGFloat
        let heightScale: CGFloat
        let rotation: Double
    }

    private let marks: [NailMarkSpec] = [
        .init(x: 0.26, y: 0.34, widthScale: 1.00, heightScale: 1.00, rotation: -6),
        .init(x: 0.37, y: 0.23, widthScale: 0.96, heightScale: 0.90, rotation: -3),
        .init(x: 0.49, y: 0.21, widthScale: 0.90, heightScale: 0.86, rotation: 1),
        .init(x: 0.61, y: 0.24, widthScale: 0.84, heightScale: 0.84, rotation: 4),
        .init(x: 0.72, y: 0.30, widthScale: 0.78, heightScale: 0.78, rotation: 6)
    ]

    var body: some View {
        // Keep ratio-based placement so the placeholder stays visually centered in the card across size changes.
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let markWidth = size * 0.17
            let markHeight = size * 0.07

            ZStack {
                NailDesignHandShape()
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: 1.4,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [4, 3]
                        )
                    )

                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                    NailMarkMiniShape()
                        .stroke(
                            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round, dash: [2.5, 2.5])
                        )
                        .frame(
                            width: markWidth * mark.widthScale,
                            height: markHeight * mark.heightScale
                        )
                        .rotationEffect(.degrees(mark.rotation))
                        .position(
                            x: geometry.size.width * mark.x,
                            y: geometry.size.height * mark.y
                        )
                }
            }
            .foregroundStyle(AIGenerationDesignTokens.placeholder)
        }
    }
}

private struct NailDesignHandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let handBase = CGRect(
            x: w * 0.22,
            y: h * 0.32,
            width: w * 0.56,
            height: h * 0.45
        )
        let fingerHeights: [CGFloat] = [0.34, 0.40, 0.46, 0.43, 0.38]
        let fingerWidths: [CGFloat] = [0.125, 0.112, 0.106, 0.100, 0.094]
        let fingerXCenters: [CGFloat] = [0.34, 0.45, 0.56, 0.67, 0.78]
        let fingerOffsets: [CGFloat] = [0.11, 0.07, 0.04, 0.05, 0.08]

        path.addPath(
            RoundedRectangle(
                cornerSize: CGSize(width: w * 0.20, height: h * 0.20),
                style: .continuous
            ).path(in: handBase)
        )

        for index in 0..<fingerWidths.count {
            let fingerWidth = w * fingerWidths[index]
            let fingerHeight = h * fingerHeights[index]
            let fingerRect = CGRect(
                x: w * fingerXCenters[index] - fingerWidth * 0.5,
                y: h * (0.18 + fingerOffsets[index]),
                width: fingerWidth,
                height: fingerHeight
            )
            path.addPath(
                Capsule(style: .continuous).path(in: fingerRect)
            )
        }

        let thumbWidth = w * 0.15
        let thumbHeight = h * 0.24
        let thumbRect = CGRect(
            x: w * 0.07,
            y: h * 0.43,
            width: thumbWidth,
            height: thumbHeight
        )
        let thumbCenter = CGPoint(x: thumbRect.midX, y: thumbRect.midY)
        let thumbTransform = CGAffineTransform(
            translationX: thumbCenter.x,
            y: thumbCenter.y
        )
        .rotated(by: -(.pi / 8))
        .translatedBy(x: -thumbCenter.x, y: -thumbCenter.y)
        path.addPath(
            Capsule(style: .continuous).path(in: thumbRect),
            transform: thumbTransform
        )

        return path
    }
}

private struct NailMarkMiniShape: Shape {
    func path(in rect: CGRect) -> Path {
        Capsule(style: .continuous).path(in: rect)
    }
}

private struct AlmondNailPreviewShape: Shape {
    func path(in rect: CGRect) -> Path {
        return RoundedRectangle(
            cornerRadius: rect.width * 0.5,
            style: .continuous
        ).path(in: rect)
    }
}

private struct HandOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.26, y: h * 0.86))
        path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.42))
        path.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.20), control: CGPoint(x: w * 0.24, y: h * 0.24))
        path.addQuadCurve(to: CGPoint(x: w * 0.48, y: h * 0.46), control: CGPoint(x: w * 0.50, y: h * 0.24))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.23))
        path.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.22), control: CGPoint(x: w * 0.53, y: h * 0.17))
        path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.28))
        path.addQuadCurve(to: CGPoint(x: w * 0.74, y: h * 0.30), control: CGPoint(x: w * 0.70, y: h * 0.24))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.42))
        path.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.48), control: CGPoint(x: w * 0.84, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.77, y: h * 0.78))
        path.addQuadCurve(to: CGPoint(x: w * 0.61, y: h * 0.90), control: CGPoint(x: w * 0.74, y: h * 0.90))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.90))
        path.addQuadCurve(to: CGPoint(x: w * 0.26, y: h * 0.86), control: CGPoint(x: w * 0.30, y: h * 0.92))

        return path
    }
}

private struct HandPalmCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.36, y: h * 0.66))
        path.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.66), control: CGPoint(x: w * 0.50, y: h * 0.55))
        return path
    }
}

#Preview {
    NavigationStack {
        AINailGenerationView()
            .environmentObject(AppViewModel())
    }
}
