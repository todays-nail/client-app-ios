//
//  AINailGenerationView.swift
//  NailClient
//

import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct AINailGenerationView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: AINailGenerationViewModel
    @State private var selectedDetailItem: FittedAIImagesViewModel.FittedAIImageItem?
    @State private var isHandPhotoPickerPresented: Bool = false
    @State private var isDesignPhotoPickerPresented: Bool = false
    @State private var isHandPhotoSourceDialogPresented: Bool = false
    @State private var isHandCameraPresented: Bool = false
    @State private var handCropSource: HandCropSource?
    @State private var handCropErrorMessage: String?
    @State private var referenceCropSource: ReferenceCropSource?
    @State private var referenceCropErrorMessage: String?
    @State private var lastDesignPayloadApplyFailed: AIDesignSelectionPayload?
    @State private var designSelectionToast: DesignSelectionToast?
    @State private var handSelectionTask: Task<Void, Never>?
    @State private var referenceSelectionTask: Task<Void, Never>?
    @State private var pushNavigationTask: Task<Void, Never>?
    @State private var detailResolveTask: Task<Void, Never>?
    @State private var detailResolveToken: UUID?
    @State private var designSelectionToastTask: Task<Void, Never>?
    @State private var lastAppliedDesignPayloadID: UUID?
    @State private var lastAutoOpenedJobId: UUID?
    @State private var directDetailOpenSuppressedJobId: UUID?
    @State private var isResolvingDetailItem: Bool = false
    @State private var detailResolveAlert: DetailResolveAlert?
    @State private var isConsentSheetPresented: Bool = false
    private let uploadCardSpacing: CGFloat = 12
    private let uploadCardHeight: CGFloat = 180
    private let uploadCardRowHeight: CGFloat = 212
    private let squareCropAspectRatio: CGSize = .init(width: 1, height: 1)
    private let consentStore = AITransferConsentStore.shared

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: AINailGenerationViewModel())
    }

    init(viewModel: AINailGenerationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AIGenerationDesignTokens.sectionSpacing) {
                noticeCard
                photoUploadSection
                nailShapeSection
                extensionOptionSection
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
            } else if isResolvingDetailItem {
                detailResolvingOverlay
            }
        }
        .overlay(alignment: .top) {
            designSelectionToastView
                .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
                .padding(.top, 8)
        }
        .navigationTitle("AI 네일 생성")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.bind(service: appViewModel)
            viewModel.onLifecycleEvent = { event in
                appViewModel.handleAIGenerationLifecycleEvent(event)
            }
            Task {
                await appViewModel.refreshPushAuthorizationState()
            }
            applySelectedDesignIfNeeded(requireAITab: false)
            autoOpenDetailIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await appViewModel.refreshPushAuthorizationState()
            }
        }
        .onChange(of: viewModel.selectedHandPhotoItem) { _, newItem in
            handSelectionTask?.cancel()
            handSelectionTask = Task {
                await handleHandPhotoSelection(newItem)
            }
        }
        .onChange(of: viewModel.selectedReferencePhotoItem) { _, newItem in
            referenceSelectionTask?.cancel()
            referenceSelectionTask = Task {
                await handleReferencePhotoSelection(newItem)
            }
        }
        .onChange(of: viewModel.isSubmitting) { _, _ in
            autoOpenDetailIfNeeded()
        }
        .onChange(of: viewModel.resultImageURL) { _, _ in
            autoOpenDetailIfNeeded()
        }
        .onChange(of: appViewModel.selectedMainTab) { _, _ in
            autoOpenDetailIfNeeded()
        }
        .onDisappear {
            handSelectionTask?.cancel()
            handSelectionTask = nil
            referenceSelectionTask?.cancel()
            referenceSelectionTask = nil
            pushNavigationTask?.cancel()
            pushNavigationTask = nil
            detailResolveTask?.cancel()
            detailResolveTask = nil
            detailResolveToken = nil
            isResolvingDetailItem = false
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
        .photosPicker(
            isPresented: $isHandPhotoPickerPresented,
            selection: $viewModel.selectedHandPhotoItem,
            matching: .images
        )
        .photosPicker(
            isPresented: $isDesignPhotoPickerPresented,
            selection: $viewModel.selectedReferencePhotoItem,
            matching: .images
        )
        .fullScreenCover(isPresented: $isHandCameraPresented) {
            CameraCaptureView(
                onCapture: { image in
                    handleCapturedHandPhoto(image)
                },
                onCancel: {
                    isHandCameraPresented = false
                },
                onFail: { message in
                    handCropErrorMessage = message
                    isHandCameraPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isConsentSheetPresented) {
            AITransferConsentSheetView(
                onDecline: {
                    isConsentSheetPresented = false
                },
                onApprove: {
                    handleConsentApproved()
                },
                onOpenPrivacyPolicy: {
                    guard let privacyURL = AppConfig.privacyPolicyURL else { return }
                    openURL(privacyURL)
                }
            )
        }
        .sheet(item: $selectedDetailItem) { item in
            FittedAIImageDetailSheet(
                item: item,
                onLoadDetailImages: { jobId, fallbackGeneratedURL in
                    try await loadDetailImageSet(
                        jobId: jobId,
                        fallbackGeneratedURL: fallbackGeneratedURL
                    )
                },
                onToggleLike: { nextLikeState in
                    await toggleDetailLike(jobId: item.jobId, nextLikeState: nextLikeState)
                },
                onDelete: {
                    await deleteDetailItem(jobId: item.jobId)
                }
            )
        }
        .alert(item: $detailResolveAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("확인"))
            )
        }
        .fullScreenCover(item: $handCropSource, onDismiss: {
            viewModel.selectedHandPhotoItem = nil
            handCropErrorMessage = nil
        }) { source in
            DesignImageCropperView(
                sourceImage: source.image,
                title: "손 이미지 크롭",
                cropAspectRatio: squareCropAspectRatio,
                isAspectRatioLocked: true,
                isResetAspectRatioEnabled: false,
                onCancel: {
                    handCropSource = nil
                },
                onApply: { croppedData in
                    Task {
                        do {
                            try viewModel.applyCroppedHandPhotoData(croppedData)
                            handCropSource = nil
                            handCropErrorMessage = nil
                            showDesignSelectionToast(
                                kind: .success,
                                message: "손 사진이 적용되었어요."
                            )
                        } catch {
                            handCropErrorMessage = "손 사진 크롭에 실패했습니다. 다시 선택해 주세요."
                        }
                    }
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $referenceCropSource, onDismiss: {
            viewModel.selectedReferencePhotoItem = nil
            referenceCropErrorMessage = nil
        }) { source in
            DesignImageCropperView(
                sourceImage: source.image,
                title: "디자인 이미지 크롭",
                cropAspectRatio: squareCropAspectRatio,
                isAspectRatioLocked: true,
                isResetAspectRatioEnabled: false,
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
            .ignoresSafeArea()
        }
    }

    private var photoUploadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(number: 1, title: "사진 업로드")

            GeometryReader { proxy in
                let cardWidth = max(0, floor((proxy.size.width - uploadCardSpacing) / 2))

                HStack(spacing: uploadCardSpacing) {
                    handPhotoSelectionCard(
                        title: "나의 손",
                        image: viewModel.handPreviewImage,
                        placeholder: .handPhoto
                    )
                    .frame(width: cardWidth)

                    designPhotoSelectionCard(
                        title: "디자인",
                        image: viewModel.referencePreviewImage,
                        placeholder: .designPhoto
                    )
                    .frame(width: cardWidth)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: uploadCardRowHeight)
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

    private var extensionOptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(number: 3, title: "네일 연장 여부")
            Text("원본 손톱 길이를 유지할지, 자연스러운 범위 내에서 연장할지 선택해 주세요.")
                .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .medium))
                .foregroundStyle(AIGenerationDesignTokens.secondaryText)

            HStack(spacing: 12) {
                ForEach(AINailExtensionOption.allCases) { option in
                    extensionOptionCard(option)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let handCropErrorMessage {
            Text(handCropErrorMessage)
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                .foregroundStyle(.red)
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
        image: UIImage?,
        placeholder: AIPromptPlaceholderStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(AIGenerationDesignTokens.fieldTitleStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)
                .lineLimit(1)

            Button {
                isHandPhotoSourceDialogPresented = true
            } label: {
                photoSelectionCardContent(image: image, placeholder: placeholder)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "손 사진 가져오기",
                isPresented: $isHandPhotoSourceDialogPresented,
                titleVisibility: .visible
            ) {
                Button("카메라로 촬영") {
                    presentHandCameraIfAvailable()
                }
                Button("사진 보관함에서 선택") {
                    isHandPhotoPickerPresented = true
                }
                Button("취소", role: .cancel) {}
            }
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
                .lineLimit(1)

            Button {
                appViewModel.noteAIDesignSelectionSource(.photoLibrary)
                isDesignPhotoPickerPresented = true
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
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
        .frame(height: uploadCardHeight)
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

    private func extensionOptionCard(_ option: AINailExtensionOption) -> some View {
        let isSelected = viewModel.selectedExtensionOption == option

        return Button {
            viewModel.selectedExtensionOption = option
        } label: {
            VStack(spacing: 8) {
                Text(option.title)
                    .font(.system(AIGenerationDesignTokens.fieldTitleStyle, weight: .semibold))
                    .foregroundStyle(isSelected ? AIGenerationDesignTokens.accent : AIGenerationDesignTokens.secondaryText)
                Text(option == .natural ? "원래 길이 유지" : "현실적인 길이 연장")
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AIGenerationDesignTokens.cardBackground : AIGenerationDesignTokens.cardSubtleBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? AIGenerationDesignTokens.accent : AIGenerationDesignTokens.border, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(AIGenerationDesignTokens.accent)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
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
            handleSubmitButtonTap()
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

    private func handleSubmitButtonTap() {
        guard viewModel.canSubmit, !viewModel.isSubmitting else { return }
        if consentStore.hasConsent {
            submitGenerationFlow()
            return
        }
        isConsentSheetPresented = true
    }

    private func handleConsentApproved() {
        consentStore.grantConsent()
        isConsentSheetPresented = false
        submitGenerationFlow()
    }

    private func submitGenerationFlow() {
        Task {
            await appViewModel.preparePushNotificationsForAIGeneration()
            await viewModel.submitGeneration()
        }
    }

    private var generationBlockingOverlay: some View {
        GeometryReader { proxy in
            let availableHeight = proxy.size.height - 56
            let compactLayout = availableHeight < 640 || dynamicTypeSize.isAccessibilitySize
            let contentWidth = min(320, max(248, proxy.size.width - 48))
            let contentSpacing: CGFloat = compactLayout ? 22 : 28

            ZStack {
                Color.black.opacity(0.94)
                    .ignoresSafeArea()

                VStack(spacing: contentSpacing) {
                    spinnerLoadingSection(compactLayout: compactLayout)
                    generationOverlayActionButtons
                }
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
    }

    private func spinnerLoadingSection(compactLayout: Bool) -> some View {
        VStack(spacing: compactLayout ? 10 : 12) {
            Text("오늘 네일 AI가\n생성중이에요")
                .font(
                    .system(
                        compactLayout ? AIGenerationDesignTokens.secondaryBodyStyle : AIGenerationDesignTokens.bodyStyle,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .controlSize(compactLayout ? .regular : .large)
                .scaleEffect(compactLayout ? 0.95 : 1.15)

            Text(generationOverlayStatusMessage)
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)

            Text(generationOverlaySupportMessage)
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .regular))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var generationOverlayStatusMessage: String {
        let trimmed = viewModel.statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "생성 중..." : trimmed
    }

    private var generationOverlaySupportMessage: String {
        switch appViewModel.pushAuthorizationState {
        case .allowed:
            return "생성 완료되면 알림으로 알려드릴게요!"
        case .denied:
            return "알림이 꺼져 있어요. 설정에서 켜면 생성 완료를 알려드릴게요!"
        case .notDetermined:
            return "생성 완료 후 앱에서 결과를 확인할 수 있어요."
        }
    }

    private var generationOverlayActionButtons: some View {
        VStack(spacing: 10) {
            openResultsTabButton
                .frame(maxWidth: .infinity)

            if appViewModel.pushAuthorizationState == .denied {
                openNotificationSettingsButton
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var detailResolvingOverlay: some View {
        ZStack {
            AIGenerationDesignTokens.generationOverlayScrim
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AIGenerationDesignTokens.accent)
                    .controlSize(.regular)

                Text("생성 결과를 불러오는 중...")
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AIGenerationDesignTokens.generationModalBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
        }
    }

    private var openResultsTabButton: some View {
        Button {
            appViewModel.syncSelectedMainTab(.results)
        } label: {
            Text("생성 결과 보기")
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(AIGenerationDesignTokens.accent)
    }

    private var openNotificationSettingsButton: some View {
        Button {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(settingsURL)
        } label: {
            Text("알림 설정하러 가기")
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(AIGenerationDesignTokens.accent)
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

    private func autoOpenDetailIfNeeded() {
        guard appViewModel.selectedMainTab == .ai else { return }
        guard !viewModel.isSubmitting else { return }
        guard let jobId = viewModel.currentJobId else { return }
        guard lastAutoOpenedJobId != jobId else { return }
        guard directDetailOpenSuppressedJobId != jobId else { return }
        guard let detailItem = viewModel.makeAutoOpenedDetailItem() else { return }

        selectedDetailItem = detailItem
        lastAutoOpenedJobId = jobId
    }

    private func resolveAndOpenDetail(jobId: UUID) {
        guard appViewModel.selectedMainTab == .ai else { return }
        guard lastAutoOpenedJobId != jobId else { return }

        let resolveToken = UUID()
        detailResolveToken = resolveToken
        detailResolveTask?.cancel()
        detailResolveTask = Task { @MainActor in
            isResolvingDetailItem = true
            detailResolveAlert = nil
            defer {
                if detailResolveToken == resolveToken {
                    isResolvingDetailItem = false
                    detailResolveTask = nil
                    detailResolveToken = nil
                }
            }

            let clock = ContinuousClock()
            let startedAt = clock.now

            while !Task.isCancelled {
                guard appViewModel.selectedMainTab == .ai else { return }

                do {
                    let response = try await appViewModel.fetchCompletedNailGenerationList(
                        limit: 20,
                        cursor: nil,
                        likedOnly: false
                    )

                    if let matched = response.items.first(where: { $0.jobId == jobId }) {
                        selectedDetailItem = FittedAIImagesViewModel.makeItem(matched)
                        lastAutoOpenedJobId = jobId
                        return
                    }
                } catch {
                    // 목록 동기화 지연/일시 오류는 최대 대기시간 내 재시도
                }

                if startedAt.duration(to: clock.now) >= .seconds(30) {
                    detailResolveAlert = DetailResolveAlert(
                        title: "상세 불러오기 실패",
                        message: "생성 결과를 아직 찾지 못했어요. 잠시 후 다시 확인해 주세요."
                    )
                    return
                }

                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    private func loadDetailImageSet(
        jobId: UUID,
        fallbackGeneratedURL: URL?
    ) async throws -> FittedAIImagesViewModel.DetailImageSet {
        let response = try await appViewModel.getNailGenerationJobStatus(
            jobId: jobId,
            includeInputs: true
        )

        let generatedURL = response.resultImageURL.flatMap(URL.init(string:)) ?? fallbackGeneratedURL
        let handURL = response.handImageURL.flatMap(URL.init(string:))
        let referenceURL = response.referenceImageURL.flatMap(URL.init(string:))

        return .init(
            generatedURL: generatedURL,
            handURL: handURL,
            referenceURL: referenceURL
        )
    }

    private func toggleDetailLike(jobId: UUID, nextLikeState: Bool) async -> Bool {
        do {
            let response = try await appViewModel.setNailGenerationLike(
                jobId: jobId,
                isLiked: nextLikeState
            )
            if selectedDetailItem?.jobId == response.jobId {
                selectedDetailItem?.isLiked = response.isLiked
            }
            refreshResultListCaches(includeLiked: true)
            return true
        } catch {
            return false
        }
    }

    private func deleteDetailItem(jobId: UUID) async -> Bool {
        do {
            _ = try await appViewModel.deleteNailGeneration(jobId: jobId)
            if selectedDetailItem?.jobId == jobId {
                selectedDetailItem = nil
            }
            refreshResultListCaches(includeLiked: true)
            return true
        } catch {
            return false
        }
    }

    private func refreshResultListCaches(includeLiked: Bool) {
        appViewModel.refreshNailGenerationFirstPageCache(likedOnly: false)
        if includeLiked {
            appViewModel.refreshNailGenerationFirstPageCache(likedOnly: true)
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

    private func presentHandCameraIfAvailable() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            handCropErrorMessage = "이 기기에서는 카메라를 사용할 수 없습니다."
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isHandCameraPresented = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        isHandCameraPresented = true
                    } else {
                        handCropErrorMessage = "카메라 권한이 필요합니다. 설정에서 권한을 허용해 주세요."
                    }
                }
            }
        case .denied, .restricted:
            handCropErrorMessage = "카메라 권한이 꺼져 있어요. 설정 앱에서 권한을 허용해 주세요."
        @unknown default:
            handCropErrorMessage = "카메라를 사용할 수 없습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    private func handleCapturedHandPhoto(_ image: UIImage) {
        handCropSource = HandCropSource(image: image)
        handCropErrorMessage = nil
        isHandCameraPresented = false
    }

    private func handleHandPhotoSelection(_ item: PhotosPickerItem?) async {
        do {
            guard let item else {
                handCropSource = nil
                return
            }
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else {
                throw EdgeAPIError(statusCode: -1, message: "손 사진을 불러오지 못했습니다.", errorId: nil)
            }
            guard !Task.isCancelled else { return }
            handCropSource = HandCropSource(image: image)
            handCropErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            handCropSource = nil
            viewModel.selectedHandPhotoItem = nil
            handCropErrorMessage = "손 사진을 불러오지 못했습니다: \(error.localizedDescription)"
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

        directDetailOpenSuppressedJobId = jobId
        let outcome = await viewModel.openResultFromPush(jobId: jobId)
        switch outcome {
        case .opened:
            resolveAndOpenDetail(jobId: jobId)
        case .inProgress(let message):
            appViewModel.updateAIGenerationProgress(message: message)
        case .failed(let message):
            appViewModel.failAIGeneration(jobId: jobId, message: message)
        }
        appViewModel.consumePushNavigationRequest()
    }

}

private struct DetailResolveAlert: Identifiable {
    let id: UUID = UUID()
    let title: String
    let message: String
}

private struct HandCropSource: Identifiable {
    let id: UUID = UUID()
    let image: UIImage
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

#Preview("기본") {
    NavigationStack {
        AINailGenerationView()
            .environmentObject(AppViewModel())
    }
}

#if DEBUG
#Preview("생성 중 모달") {
    NavigationStack {
        AINailGenerationView(
            viewModel: .previewState(
                isSubmitting: true,
                statusMessage: "이미지 생성 중..."
            )
        )
        .environmentObject(AppViewModel())
    }
}
#endif
