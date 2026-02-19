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
    @State private var showDesignSourceSheet: Bool = false
    @State private var isDesignPhotoPickerPresented: Bool = false
    @State private var referenceCropSource: ReferenceCropSource?
    @State private var referenceCropErrorMessage: String?
    @State private var lastDesignPayloadApplyFailed: AIDesignSelectionPayload?
    @State private var designSelectionToast: DesignSelectionToast?
    @State private var referenceSelectionTask: Task<Void, Never>?
    @State private var pushNavigationTask: Task<Void, Never>?
    @State private var designSelectionToastTask: Task<Void, Never>?
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
        .overlay {
            if viewModel.isSubmitting {
                generationBlockingOverlay
            }
        }
        .overlay(alignment: .top) {
            designSelectionToastView
                .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
                .padding(.top, 8)
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
            viewModel.onLifecycleEvent = { event in
                appViewModel.handleAIGenerationLifecycleEvent(event)
            }
            applySelectedDesignIfNeeded(requireAITab: false)
        }
        .onChange(of: viewModel.selectedHandPhotoItem) { _, _ in
            Task { await viewModel.loadHandPhoto() }
        }
        .onChange(of: viewModel.selectedReferencePhotoItem) { _, newItem in
            referenceSelectionTask?.cancel()
            referenceSelectionTask = Task {
                await handleReferencePhotoSelection(newItem)
            }
        }
        .onDisappear {
            referenceSelectionTask?.cancel()
            referenceSelectionTask = nil
            pushNavigationTask?.cancel()
            pushNavigationTask = nil
            designSelectionToastTask?.cancel()
            designSelectionToastTask = nil
        }
        .onChange(of: appViewModel.selectedAIDesignPayload) { _, _ in
            applySelectedDesignIfNeeded(requireAITab: true, showsToast: true)
        }
        .onChange(of: appViewModel.pushNavigationToken) { _, token in
            guard token != nil else { return }
            pushNavigationTask?.cancel()
            pushNavigationTask = Task {
                await handlePushNavigationRequest()
            }
        }
        .onChange(of: appViewModel.aiResultOpenRequestToken) { _, token in
            guard token != nil else { return }
            if viewModel.resultImageURL != nil {
                showResultView = true
            }
            appViewModel.consumeAIResultOpenRequest()
        }
        .sheet(isPresented: $showDesignSourceSheet) {
            AIDesignSourceSheetView(
                previewImage: viewModel.referencePreviewImage,
                hasReferenceImage: viewModel.hasReferenceImage,
                lastSource: appViewModel.lastAIDesignSource,
                onSelectPhotoLibrary: {
                    showDesignSourceSheet = false
                    appViewModel.noteAIDesignSelectionSource(.photoLibrary)
                    isDesignPhotoPickerPresented = true
                },
                onRepeatLastSource: {
                    showDesignSourceSheet = false
                    selectFromLastDesignSource()
                },
                onClearReference: {
                    viewModel.clearReferenceImage()
                    appViewModel.clearSelectedAIDesignPayload()
                    lastAppliedDesignPayloadID = nil
                    lastDesignPayloadApplyFailed = nil
                    showDesignSourceSheet = false
                    showDesignSelectionToast(
                        kind: .success,
                        message: "현재 디자인을 제거했어요."
                    )
                },
                onClose: {
                    showDesignSourceSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .sheet(item: $referenceCropSource, onDismiss: {
            viewModel.selectedReferencePhotoItem = nil
            referenceCropErrorMessage = nil
        }) { source in
            DesignImageCropperView(
                sourceImage: source.image,
                onCancel: {
                    referenceCropSource = nil
                },
                onApply: { croppedData in
                    Task {
                        do {
                            try viewModel.applyCroppedReferencePhotoData(croppedData)
                            referenceCropSource = nil
                            referenceCropErrorMessage = nil
                            lastDesignPayloadApplyFailed = nil
                            showDesignSelectionToast(
                                kind: .success,
                                message: "디자인 사진이 적용되었어요."
                            )
                        } catch {
                            referenceCropErrorMessage = "디자인 사진 크롭에 실패했습니다. 다시 선택해 주세요."
                        }
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
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

        if let referenceCropErrorMessage {
            Text(referenceCropErrorMessage)
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                .foregroundStyle(.red)
        }

        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                .foregroundStyle(.red)
        }

        if lastDesignPayloadApplyFailed != nil {
            Button {
                retryFailedDesignPayloadApply()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("선택한 디자인 다시 적용")
                }
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("선택한 디자인 다시 적용")
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
                showDesignSourceSheet = true
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
                case .handPhoto, .designPhoto:
                    Image(systemName: "hand.raised")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
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
            Task {
                await appViewModel.preparePushNotificationsForAIGeneration()
                await viewModel.submitGeneration()
            }
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

    private var generationBlockingOverlay: some View {
        ZStack {
            AIGenerationDesignTokens.generationOverlayScrim
                .ignoresSafeArea()

            VStack(spacing: 16) {
                NailGeneratingView(
                    configuration: .init(
                        nailSize: CGSize(width: 118, height: 176),
                        showSecondaryText: true,
                        showsBackground: false
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 246)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("완료되면 알려드릴게요.")
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("AI 화면에 머무르기") {
                        isPromptFocused = false
                    }
                    .buttonStyle(.bordered)

                    Button("생성 결과 보기") {
                        isPromptFocused = false
                        appViewModel.syncSelectedMainTab(.results)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AIGenerationDesignTokens.accent)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(18)
            .frame(maxWidth: 320, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AIGenerationDesignTokens.generationModalBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.20), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 24)
        }
    }

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.userPrompt },
            set: { viewModel.updatePrompt($0) }
        )
    }

    @ViewBuilder
    private var designSelectionToastView: some View {
        if let toast = designSelectionToast {
            HStack(spacing: 8) {
                Image(systemName: toast.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(toast.iconColor)
                Text(toast.message)
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(toast.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            .onTapGesture {
                dismissDesignSelectionToast()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func applySelectedDesignIfNeeded(requireAITab: Bool, showsToast: Bool = false) {
        guard let payload = appViewModel.selectedAIDesignPayload else { return }
        if payload.id == lastAppliedDesignPayloadID { return }
        if requireAITab && appViewModel.selectedMainTab != .ai { return }

        Task {
            let applied = await viewModel.applySelectedDesignPayload(payload)
            await MainActor.run {
                if applied {
                    lastAppliedDesignPayloadID = payload.id
                    lastDesignPayloadApplyFailed = nil
                    if showsToast {
                        showDesignSelectionToast(
                            kind: .success,
                            message: "선택한 디자인이 적용되었어요."
                        )
                    }
                    return
                }
                lastDesignPayloadApplyFailed = payload
                if showsToast {
                    showDesignSelectionToast(
                        kind: .failure,
                        message: "디자인 적용에 실패했어요. 다시 시도해 주세요."
                    )
                }
            }
        }
    }

    private func retryFailedDesignPayloadApply() {
        guard lastDesignPayloadApplyFailed != nil else { return }
        applySelectedDesignIfNeeded(requireAITab: false, showsToast: true)
    }

    private func selectFromLastDesignSource() {
        guard let source = appViewModel.lastAIDesignSource else { return }
        switch source {
        case .photoLibrary:
            appViewModel.noteAIDesignSelectionSource(.photoLibrary)
            isDesignPhotoPickerPresented = true
        }
    }

    private func showDesignSelectionToast(kind: DesignSelectionToast.Kind, message: String) {
        designSelectionToastTask?.cancel()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            designSelectionToast = DesignSelectionToast(kind: kind, message: message)
        }

        designSelectionToastTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismissDesignSelectionToast()
            }
        }
    }

    private func dismissDesignSelectionToast() {
        designSelectionToastTask?.cancel()
        designSelectionToastTask = nil
        withAnimation(.easeOut(duration: 0.2)) {
            designSelectionToast = nil
        }
    }

    private func handleReferencePhotoSelection(_ item: PhotosPickerItem?) async {
        do {
            guard let item else {
                referenceCropSource = nil
                return
            }
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                throw EdgeAPIError(statusCode: -1, message: "디자인 사진을 불러오지 못했습니다.", errorId: nil)
            }
            guard !Task.isCancelled else { return }
            referenceCropSource = ReferenceCropSource(image: image)
            referenceCropErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            referenceCropSource = nil
            viewModel.selectedReferencePhotoItem = nil
            referenceCropErrorMessage = "디자인 사진을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func handlePushNavigationRequest() async {
        guard let jobId = appViewModel.pendingPushJobId else {
            appViewModel.consumePushNavigationRequest()
            return
        }

        let outcome = await viewModel.openResultFromPush(jobId: jobId)
        switch outcome {
        case .opened:
            showResultView = true
        case .inProgress(let message):
            appViewModel.updateAIGenerationProgress(message: message)
        case .failed(let message):
            appViewModel.failAIGeneration(jobId: jobId, message: message)
        }
        appViewModel.consumePushNavigationRequest()
    }

}

private struct ReferenceCropSource: Identifiable {
    let id: UUID = UUID()
    let image: UIImage
}

private struct DesignSelectionToast: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case failure
    }

    let id: UUID = UUID()
    let kind: Kind
    let message: String

    var iconName: String {
        switch kind {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.triangle.fill"
        }
    }

    var iconColor: Color {
        switch kind {
        case .success:
            return AIGenerationDesignTokens.globalBannerSuccessIcon
        case .failure:
            return AIGenerationDesignTokens.globalBannerFailureIcon
        }
    }

    var backgroundColor: Color {
        switch kind {
        case .success:
            return AIGenerationDesignTokens.globalBannerSuccessBackground
        case .failure:
            return AIGenerationDesignTokens.globalBannerFailureBackground
        }
    }
}

private enum AIPromptPlaceholderStyle {
    case handPhoto
    case designPhoto
}

private struct AlmondNailPreviewShape: Shape {
    func path(in rect: CGRect) -> Path {
        return RoundedRectangle(
            cornerRadius: rect.width * 0.5,
            style: .continuous
        ).path(in: rect)
    }
}

#Preview {
    NavigationStack {
        AINailGenerationView()
            .environmentObject(AppViewModel())
    }
}
