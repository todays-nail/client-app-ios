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
            .padding(.top, 20)
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
        }
        .onChange(of: viewModel.selectedHandPhotoItem) { _ in
            Task { await viewModel.loadHandPhoto() }
        }
        .onChange(of: viewModel.selectedReferencePhotoItem) { _ in
            Task { await viewModel.loadReferencePhoto() }
        }
        .onChange(of: viewModel.resultImageURL) { resultImageURL in
            showResultView = (resultImageURL != nil)
        }
    }

    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(number: 1, title: "사진 업로드")

            HStack(spacing: 12) {
                photoSelectionCard(
                    title: "나의 손",
                    selection: $viewModel.selectedHandPhotoItem,
                    image: viewModel.handPreviewImage
                )
                photoSelectionCard(
                    title: "레퍼런스",
                    selection: $viewModel.selectedReferencePhotoItem,
                    image: viewModel.referencePreviewImage
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

    private func photoSelectionCard(
        title: String,
        selection: Binding<PhotosPickerItem?>,
        image: UIImage?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(AIGenerationDesignTokens.fieldTitleStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)

            PhotosPicker(selection: selection, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous)
                        .fill(AIGenerationDesignTokens.cardBackground)

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(AIGenerationDesignTokens.placeholder)
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
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func shapePreview(_ shape: AINailShape) -> some View {
        Group {
            switch shape {
            case .almond:
                Capsule(style: .continuous)
                    .fill(AIGenerationDesignTokens.shapeFill)
                    .frame(width: 44, height: 56)
            case .square:
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AIGenerationDesignTokens.shapeFill)
                    .frame(width: 42, height: 52)
            case .round:
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AIGenerationDesignTokens.shapeFill)
                    .frame(width: 44, height: 54)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                .frame(width: shape == .square ? 42 : 44, height: shape == .square ? 52 : (shape == .almond ? 56 : 54))
        )
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
                    .font(.system(AIGenerationDesignTokens.bodyStyle, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.clear)
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

            Text("AI가 손 모양과 레퍼런스를 분석하여 최적의 디자인을 제안합니다. 실제 시술 환경에 따라 결과물에 미세한 차이가 발생할 수 있습니다.")
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

}

#Preview {
    NavigationStack {
        AINailGenerationView()
            .environmentObject(AppViewModel())
    }
}
