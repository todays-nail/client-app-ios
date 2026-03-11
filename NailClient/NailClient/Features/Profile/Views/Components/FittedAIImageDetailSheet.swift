//
//  FittedAIImageDetailSheet.swift
//  NailClient
//

import Photos
import OSLog
import SwiftUI
import UIKit
import NailUI

struct FittedAIImageDetailSheet: View {
    struct AlertMessage: Identifiable {
        let id: String
        let title: String
        let message: String
    }

    private enum GallerySlot: Int, CaseIterable, Identifiable {
        case generated
        case hand
        case reference

        var id: Int { rawValue }

        var shortTitle: String {
            switch self {
            case .generated:
                return "결과"
            case .hand:
                return "원본 손"
            case .reference:
                return "디자인"
            }
        }
    }

    private enum GalleryResolvedAsset: Equatable {
        case image(URL)
        case placeholder
    }

    @Environment(\.dismiss) private var dismiss
    let item: FittedAIImagesViewModel.FittedAIImageDetailItem
    let onLoadDetailImages: @MainActor (UUID, URL?) async throws -> FittedAIImagesViewModel.DetailLoadResult
    let onToggleLike: @MainActor (Bool) async -> Bool
    let onDelete: @MainActor () async -> Bool

    @State private var isLikeUpdating: Bool = false
    @State private var isLiked: Bool
    @State private var selectedGalleryIndex: Int = 0
    @State private var detailLoadResult: FittedAIImagesViewModel.DetailLoadResult?
    @State private var resolvedGalleryAssets: [GallerySlot: GalleryResolvedAsset] = [:]
    @State private var isGalleryLoading: Bool = false
    @State private var hasRevealedGallery: Bool = false
    @State private var galleryErrorMessage: String?
    @State private var activeAlert: AlertMessage?
    @State private var isDeleting: Bool = false
    @State private var isDownloading: Bool = false
    @State private var showDeleteConfirmAlert: Bool = false
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isScrollEnabled: Bool = false
    @State private var detailOpenedAt: Date = .now
    @State private var didLogDetailOpen: Bool = false
    @State private var detailLogId: String = AppLog.makeErrorId()

    init(
        item: FittedAIImagesViewModel.FittedAIImageDetailItem,
        onLoadDetailImages: @escaping @MainActor (UUID, URL?) async throws -> FittedAIImagesViewModel.DetailLoadResult,
        onToggleLike: @escaping @MainActor (Bool) async -> Bool,
        onDelete: @escaping @MainActor () async -> Bool
    ) {
        self.item = item
        self.onLoadDetailImages = onLoadDetailImages
        self.onToggleLike = onToggleLike
        self.onDelete = onDelete
        _isLiked = State(initialValue: item.isLiked)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    gallerySection

                    if let galleryErrorMessage {
                        inlineGalleryError(message: galleryErrorMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 22)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: DetailSheetContentHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
            }
            .scrollDisabled(!isScrollEnabled)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: DetailSheetViewportHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationTitle("오늘 네일 AI 피팅 상세")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadDetailImagesIfNeeded()
            }
            .onAppear {
                logDetailOpenedIfNeeded()
            }
            .onChange(of: selectedGalleryIndex) { _, nextIndex in
                guard hasRevealedGallery else { return }
                prefetchAdjacentGalleryImages(around: nextIndex)
            }
            .onPreferenceChange(DetailSheetContentHeightPreferenceKey.self) { nextHeight in
                contentHeight = nextHeight
                updateScrollState()
            }
            .onPreferenceChange(DetailSheetViewportHeightPreferenceKey.self) { nextHeight in
                viewportHeight = nextHeight
                updateScrollState()
            }
            .interactiveDismissDisabled(isDeleting)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await toggleLike() }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .appTypography(size: 18, weight: .bold)
                            .foregroundStyle(isLiked ? ProfileDesignTokens.destructive : ProfileDesignTokens.primaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLikeUpdating || isDeleting)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                    .accessibilityLabel(isLiked ? "좋아요 해제" : "좋아요")
                }
            }
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("확인"))
                )
            }
            .alert("정말 삭제하시겠습니까?", isPresented: $showDeleteConfirmAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제하기", role: .destructive) {
                    Task { await deleteItem() }
                }
            } message: {
                Text("삭제한 이미지는 복구할 수 없어요.")
            }
        }
    }

    @ViewBuilder
    private var gallerySection: some View {
        VStack(spacing: 12) {
            if !hasRevealedGallery {
                gallerySkeleton
            } else {
                TabView(selection: $selectedGalleryIndex) {
                    ForEach(GallerySlot.allCases) { slot in
                        galleryPage(for: slot)
                            .tag(slot.rawValue)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: 560)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    galleryHeader
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(alignment: .top, spacing: 8) {
                    ForEach(GallerySlot.allCases) { slot in
                        galleryThumbnail(for: slot)
                    }
                }
            }

            galleryActionRow
        }
    }

    private var gallerySkeleton: some View {
        VStack(spacing: 12) {
            galleryMainSkeleton

            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 6) {
                        galleryThumbnailSkeleton

                        SkeletonBlock(height: 12, cornerRadius: 6)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func galleryPage(for slot: GallerySlot) -> some View {
        let imageURL = galleryURL(for: slot)

        ZStack {
            if let imageURL {
                NailRemoteImage(
                    url: imageURL,
                    targetSize: CGSize(width: 720, height: 720),
                    resizeMode: .fit
                ) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(ProfileDesignTokens.cardBackground)
                    case .empty:
                        galleryLoadingPlaceholder(cornerRadius: 14)
                    case .failure:
                        galleryPlaceholder(title: slot.shortTitle)
                    @unknown default:
                        galleryPlaceholder(title: slot.shortTitle)
                    }
                }
            } else {
                galleryPlaceholder(title: slot.shortTitle)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func galleryThumbnail(for slot: GallerySlot) -> some View {
        Button {
            selectedGalleryIndex = slot.rawValue
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if let imageURL = galleryURL(for: slot) {
                        NailRemoteImage(
                            url: imageURL,
                            targetSize: CGSize(width: 180, height: 180),
                            resizeMode: .fill
                        ) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty:
                                Color.clear
                            case .failure:
                                thumbnailPlaceholder
                            @unknown default:
                                thumbnailPlaceholder
                            }
                        }
                    } else {
                        thumbnailPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(ProfileDesignTokens.aiHistoryPromptBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            selectedGalleryIndex == slot.rawValue
                                ? ProfileDesignTokens.accent
                                : ProfileDesignTokens.cardBorder,
                            lineWidth: selectedGalleryIndex == slot.rawValue ? 2 : 1
                        )
                )

                Text(slot.shortTitle)
                    .appTypography(size: 11, weight: .semibold)
                    .foregroundStyle(
                        selectedGalleryIndex == slot.rawValue
                            ? ProfileDesignTokens.accent
                            : ProfileDesignTokens.secondaryText
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var thumbnailPlaceholder: some View {
        Image(systemName: "photo")
            .appTypography(size: 16, weight: .medium)
            .foregroundStyle(ProfileDesignTokens.sectionTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var galleryMainSkeleton: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(FeedDesignTokens.skeletonBase)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .shimmer()
            .accessibilityHidden(true)
    }

    private var galleryThumbnailSkeleton: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(FeedDesignTokens.skeletonBase)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .shimmer()
            .accessibilityHidden(true)
    }

    private func galleryLoadingPlaceholder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(FeedDesignTokens.skeletonBase)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shimmer()
            .accessibilityHidden(true)
    }

    private func galleryPlaceholder(title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .appTypography(size: 26, weight: .semibold)
            Text("\(title) 이미지를 불러올 수 없어요")
                .appTypography(size: 13, weight: .medium)
        }
        .foregroundStyle(ProfileDesignTokens.secondaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ProfileDesignTokens.aiHistoryPromptBackground)
    }

    private func galleryURL(for slot: GallerySlot) -> URL? {
        switch resolvedGalleryAssets[slot] {
        case let .image(url):
            return url
        case .placeholder, nil:
            return nil
        }
    }

    private var selectedShapeOption: AINailShape? {
        guard let shape = detailLoadResult?.shape ?? item.shape else { return nil }
        return AINailShape(rawValue: shape.rawValue)
    }

    private var extensionModeDisplayText: String? {
        switch detailLoadResult?.extensionMode ?? item.extensionMode {
        case .extend:
            return "연장"
        case .natural:
            return "미연장"
        case nil:
            return nil
        }
    }

    private var settingsChipTexts: [String] {
        var chips: [String] = []
        if let shapeTitle = selectedShapeOption?.title {
            chips.append(shapeTitle)
        }
        if let extensionModeDisplayText {
            chips.append(extensionModeDisplayText)
        }
        return chips
    }

    private var settingsMetadataText: String? {
        guard !settingsChipTexts.isEmpty else { return nil }
        return settingsChipTexts.joined(separator: " · ")
    }

    private var galleryHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            if let settingsMetadataText {
                Text(settingsMetadataText)
                    .appTypography(size: 12, weight: .medium)
                    .foregroundStyle(.white.opacity(0.90))
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("설정 정보, \(settingsMetadataText)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 14)
        .padding(.top, 14)
        .allowsHitTesting(false)
    }

    private var galleryActionRow: some View {
        VStack(spacing: 10) {
            DetailSheetActionButton(
                title: isDownloading ? "저장 중..." : "AI 네일 저장하기",
                variant: .primary,
                isDisabled: isDownloading || isDeleting
            ) {
                Task { await downloadGeneratedImage() }
            }
            .accessibilityLabel("AI 네일 저장하기")

            DetailSheetActionButton(
                title: isDeleting ? "삭제 중..." : "삭제하기",
                variant: .destructive,
                role: .destructive,
                isDisabled: isDeleting
            ) {
                showDeleteConfirmAlert = true
            }
            .accessibilityLabel("이미지 삭제")
        }
    }

    private func inlineGalleryError(message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .appTypography(size: 12, weight: .bold)
                .foregroundStyle(ProfileDesignTokens.destructive)
                .padding(.top, 1)

            Text(message)
                .appTypography(size: 12, weight: .medium)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Button("다시 시도") {
                Task { await loadDetailImagesIfNeeded(force: true) }
            }
            .appTypography(size: 12, weight: .bold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
        )
    }

    private func loadDetailImagesIfNeeded(force: Bool = false) async {
        guard !isGalleryLoading else { return }
        if hasRevealedGallery && !force { return }

        isGalleryLoading = true
        if force {
            galleryErrorMessage = nil
            hasRevealedGallery = false
        }
        defer { isGalleryLoading = false }

        logDetailLoadStarted(force: force)

        do {
            let loaded = try await onLoadDetailImages(item.jobId, item.generatedImageURLForDetail)
            logDetailStatusReady()
            let resolvedAssets = await resolveGalleryAssets(from: loaded)
            detailLoadResult = loaded
            isLiked = loaded.isLiked
            resolvedGalleryAssets = resolvedAssets
            galleryErrorMessage = nil
            hasRevealedGallery = true
            logDetailAssetsResolved(resolvedAssets)
            logDetailRevealed()
            prefetchGalleryThumbnails(from: loaded)
            prefetchAdjacentGalleryImages(around: selectedGalleryIndex)
        } catch {
            let fallback = FittedAIImagesViewModel.DetailLoadResult(
                generatedURL: item.generatedImageURLForDetail,
                handURL: nil,
                referenceURL: nil,
                shape: item.shape,
                extensionMode: item.extensionMode,
                parentJobId: item.parentJobId,
                refinementTurn: item.refinementTurn,
                isLiked: item.isLiked
            )
            let resolvedAssets = await resolveGalleryAssets(from: fallback)
            detailLoadResult = fallback
            isLiked = fallback.isLiked
            resolvedGalleryAssets = resolvedAssets
            galleryErrorMessage = "입력 이미지를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            hasRevealedGallery = true
            logDetailAssetsResolved(resolvedAssets)
            logDetailRevealed()
            prefetchGalleryThumbnails(from: fallback)
            prefetchAdjacentGalleryImages(around: selectedGalleryIndex)
        }
    }

    private func updateScrollState() {
        guard viewportHeight > 0 else {
            isScrollEnabled = false
            return
        }

        isScrollEnabled = contentHeight > (viewportHeight + 1)
    }

    private func prefetchAdjacentGalleryImages(around index: Int) {
        let slots = GallerySlot.allCases
        var urls: [URL] = []

        let previousIndex = index - 1
        if previousIndex >= 0, previousIndex < slots.count,
           let previousURL = galleryURL(for: slots[previousIndex]) {
            urls.append(previousURL)
        }

        let nextIndex = index + 1
        if nextIndex >= 0, nextIndex < slots.count,
           let nextURL = galleryURL(for: slots[nextIndex]) {
            urls.append(nextURL)
        }

        NailImagePipeline.prefetch(
            urls: urls,
            targetSize: CGSize(width: 420, height: 420),
            resizeMode: .fit
        )
    }

    private func resolveGalleryAssets(
        from detail: FittedAIImagesViewModel.DetailLoadResult
    ) async -> [GallerySlot: GalleryResolvedAsset] {
        let slotURLs: [GallerySlot: URL?] = [
            .generated: detail.generatedURL,
            .hand: detail.handURL,
            .reference: detail.referenceURL,
        ]

        let warmupRequests = slotURLs.flatMap { slot, url -> [NailImageWarmupRequest] in
            guard let url else { return [] }
            return [
                NailImageWarmupRequest(
                    id: "\(slot.id)-main",
                    url: url,
                    targetSize: CGSize(width: 720, height: 720),
                    resizeMode: .fit
                )
            ]
        }
        logDetailWarmupStarted(requestCount: warmupRequests.count)
        let warmedIDs = await NailImagePipeline.warmImagesToMemory(requests: warmupRequests)
        logDetailWarmupFinished(requestCount: warmupRequests.count, warmedCount: warmedIDs.count)

        var resolvedAssets: [GallerySlot: GalleryResolvedAsset] = [:]
        for slot in GallerySlot.allCases {
            guard let url = slotURLs[slot] ?? nil else {
                resolvedAssets[slot] = .placeholder
                continue
            }

            let mainID = "\(slot.id)-main"
            if warmedIDs.contains(mainID) {
                resolvedAssets[slot] = .image(url)
            } else {
                resolvedAssets[slot] = .placeholder
            }
        }

        return resolvedAssets
    }

    private func prefetchGalleryThumbnails(from detail: FittedAIImagesViewModel.DetailLoadResult) {
        let urls = [
            detail.generatedURL,
            detail.handURL,
            detail.referenceURL,
        ].compactMap { $0 }

        guard !urls.isEmpty else { return }

        NailImagePipeline.prefetch(
            urls: urls,
            targetSize: CGSize(width: 180, height: 180),
            resizeMode: .fill
        )
    }

    private func logDetailOpenedIfNeeded() {
        guard !didLogDetailOpen else { return }
        didLogDetailOpen = true
        detailOpenedAt = .now
        detailLogId = AppLog.makeErrorId()
        logDetail("results_detail_opened job=\(String(item.jobId.uuidString.prefix(8)))")
    }

    private func logDetailLoadStarted(force: Bool) {
        logDetail("results_detail_load_started force=\(force)")
    }

    private func logDetailStatusReady() {
        logDetail("results_detail_status_ready elapsed_ms=\(elapsedMilliseconds)")
    }

    private func logDetailWarmupStarted(requestCount: Int) {
        logDetail("results_detail_warmup_started elapsed_ms=\(elapsedMilliseconds) count=\(requestCount)")
    }

    private func logDetailWarmupFinished(requestCount: Int, warmedCount: Int) {
        logDetail("results_detail_warmup_finished elapsed_ms=\(elapsedMilliseconds) count=\(requestCount) warmed=\(warmedCount)")
    }

    private func logDetailAssetsResolved(_ assets: [GallerySlot: GalleryResolvedAsset]) {
        let readyCount = assets.values.reduce(into: 0) { count, asset in
            if case .image = asset {
                count += 1
            }
        }
        let placeholderCount = assets.count - readyCount
        logDetail("results_detail_assets_resolved elapsed_ms=\(elapsedMilliseconds) ready=\(readyCount) placeholder=\(placeholderCount)")
    }

    private func logDetailRevealed() {
        logDetail("results_detail_revealed elapsed_ms=\(elapsedMilliseconds)")
    }

    private var elapsedMilliseconds: Int {
        max(0, Int(Date().timeIntervalSince(detailOpenedAt) * 1000))
    }

    private func logDetail(_ message: String) {
        AppLog.ui.debug("\(AppLog.prefix(detailLogId, "UI")) \(message)")
    }

    private func toggleLike() async {
        guard !isLikeUpdating else { return }

        let previousLikeState = isLiked
        let nextLikeState = !isLiked

        isLikeUpdating = true
        defer { isLikeUpdating = false }
        isLiked = nextLikeState

        let succeeded = await onToggleLike(nextLikeState)
        if !succeeded {
            isLiked = previousLikeState
            activeAlert = AlertMessage(
                id: UUID().uuidString,
                title: "좋아요 변경 실패",
                message: "좋아요 변경에 실패했어요. 잠시 후 다시 시도해 주세요."
            )
        }
    }

    private func deleteItem() async {
        guard !isDeleting else { return }

        isDeleting = true
        defer { isDeleting = false }

        let succeeded = await onDelete()
        if succeeded {
            dismiss()
        } else {
            activeAlert = AlertMessage(
                id: UUID().uuidString,
                title: "삭제 실패",
                message: "이미지 삭제에 실패했어요. 잠시 후 다시 시도해 주세요."
            )
        }
    }

    private func downloadGeneratedImage() async {
        guard !isDownloading else { return }
        guard let targetURL = detailLoadResult?.generatedURL ?? item.generatedImageURLForDetail else {
            activeAlert = AlertMessage(
                id: UUID().uuidString,
                title: "저장 실패",
                message: "저장할 생성 결과 이미지를 찾지 못했습니다."
            )
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        do {
            var request = URLRequest(url: targetURL)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data)
            else {
                throw DownloadError.invalidImageData
            }

            try await saveImageToPhotoLibrary(image)
            activeAlert = AlertMessage(
                id: UUID().uuidString,
                title: "저장 완료",
                message: "생성 결과 이미지가 사진 보관함에 저장되었습니다."
            )
        } catch DownloadError.photoPermissionDenied {
            activeAlert = AlertMessage(
                id: UUID().uuidString,
                title: "권한 필요",
                message: "사진 저장 권한이 필요합니다. 설정에서 권한을 허용해 주세요."
            )
        } catch {
            activeAlert = AlertMessage(
                id: UUID().uuidString,
                title: "저장 실패",
                message: "이미지 저장 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요."
            )
        }
    }

    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw DownloadError.photoPermissionDenied
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? DownloadError.saveFailed)
                }
            }
        }
    }
}

private struct DetailSheetActionButton: View {
    enum Variant {
        case primary
        case destructive
    }

    let title: String
    let variant: Variant
    var role: ButtonRole? = nil
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .appTypography(size: 15, weight: .semibold)
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(backgroundShape)
                .contentShape(RoundedRectangle(cornerRadius: AppRadiusTokens.md, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.62 : 1)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .destructive:
            return ProfileDesignTokens.destructive
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        let shape = RoundedRectangle(cornerRadius: AppRadiusTokens.md, style: .continuous)

        switch variant {
        case .primary:
            shape
                .fill(ProfileDesignTokens.accent)
                .overlay(
                    shape.stroke(ProfileDesignTokens.accent, lineWidth: 1)
                )
        case .destructive:
            shape
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    shape.stroke(ProfileDesignTokens.destructive.opacity(0.24), lineWidth: 1)
                )
        }
    }
}

private enum DownloadError: Error {
    case invalidImageData
    case photoPermissionDenied
    case saveFailed
}

private struct DetailSheetContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DetailSheetViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
private enum FittedAIImageDetailSheetPreviewData {
    static let generatedURL = URL(string: "https://picsum.photos/seed/nail-generated/720/720")
    static let handURL = URL(string: "https://picsum.photos/seed/nail-hand/720/720")
    static let referenceURL = URL(string: "https://picsum.photos/seed/nail-reference/720/720")

    static let item: FittedAIImagesViewModel.FittedAIImageDetailItem = {
        let listItem = FittedAIImagesViewModel.FittedAIImageItem(
            jobId: UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID(),
            thumbnailURL: Self.generatedURL,
            createdAt: Date(timeIntervalSince1970: 1_746_662_400),
            isLiked: true
        )
        return FittedAIImagesViewModel.previewDetailItem(
            from: listItem,
            shape: .almond,
            extensionMode: .extend
        )
    }()

    static let detailLoadResult = FittedAIImagesViewModel.DetailLoadResult(
        generatedURL: generatedURL,
        handURL: handURL,
        referenceURL: referenceURL,
        shape: .almond,
        extensionMode: .extend,
        parentJobId: nil,
        refinementTurn: 0,
        isLiked: true
    )
}

#Preview("AI 피팅 상세") {
    FittedAIImageDetailSheet(
        item: FittedAIImageDetailSheetPreviewData.item,
        onLoadDetailImages: { _, _ in
            FittedAIImageDetailSheetPreviewData.detailLoadResult
        },
        onToggleLike: { nextLikeState in
            nextLikeState
        },
        onDelete: {
            false
        }
    )
}
#endif
