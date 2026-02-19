//
//  FittedAIImageDetailSheet.swift
//  NailClient
//

import SwiftUI

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

        var badgeTitle: String {
            switch self {
            case .generated:
                return "1 결과"
            case .hand:
                return "2 원본 손"
            case .reference:
                return "3 디자인"
            }
        }

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

    @Environment(\.dismiss) private var dismiss
    let item: FittedAIImagesViewModel.FittedAIImageItem
    let onLoadDetailImages: @MainActor (UUID, URL?) async throws -> FittedAIImagesViewModel.DetailImageSet
    let onToggleLike: @MainActor (Bool) async -> Bool
    let onDelete: @MainActor () async -> Bool

    @State private var isLikeUpdating: Bool = false
    @State private var isLiked: Bool
    @State private var selectedGalleryIndex: Int = 0
    @State private var detailImageSet: FittedAIImagesViewModel.DetailImageSet
    @State private var isGalleryLoading: Bool = false
    @State private var hasLoadedDetailImages: Bool = false
    @State private var galleryErrorMessage: String?
    @State private var activeAlert: AlertMessage?
    @State private var isDeleting: Bool = false
    @State private var showDeleteConfirmAlert: Bool = false

    init(
        item: FittedAIImagesViewModel.FittedAIImageItem,
        onLoadDetailImages: @escaping @MainActor (UUID, URL?) async throws -> FittedAIImagesViewModel.DetailImageSet,
        onToggleLike: @escaping @MainActor (Bool) async -> Bool,
        onDelete: @escaping @MainActor () async -> Bool
    ) {
        self.item = item
        self.onLoadDetailImages = onLoadDetailImages
        self.onToggleLike = onToggleLike
        self.onDelete = onDelete
        _isLiked = State(initialValue: item.isLiked)
        _detailImageSet = State(
            initialValue: .init(
                generatedURL: item.imageURL,
                handURL: nil,
                referenceURL: nil
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    gallerySection

                    if let galleryErrorMessage {
                        inlineGalleryError(message: galleryErrorMessage)
                    }

                    if shouldShowSettingsSection {
                        sectionCard(title: "설정") {
                            HStack(alignment: .center, spacing: 12) {
                                if let selectedShapeOption {
                                    shapeSettingCard(selectedShapeOption)
                                }

                                Spacer(minLength: 0)

                                if let extensionModeDisplayText {
                                    extensionModeCard(extensionModeDisplayText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    footerMetaRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 22)
            }
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationTitle("오늘 네일 AI 피팅 상세")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadDetailImagesIfNeeded()
            }
            .interactiveDismissDisabled(isDeleting)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }
            }
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
    }

    @ViewBuilder
    private var gallerySection: some View {
        if isGalleryLoading && !hasLoadedDetailImages {
            gallerySkeleton
        } else {
            VStack(spacing: 10) {
                TabView(selection: $selectedGalleryIndex) {
                    ForEach(GallerySlot.allCases) { slot in
                        galleryPage(for: slot)
                            .tag(slot.rawValue)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Button {
                        Task { await toggleLike() }
                    } label: {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .appTypography(size: 18, weight: .bold)
                            .foregroundStyle(isLiked ? ProfileDesignTokens.destructive : ProfileDesignTokens.secondaryText)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(ProfileDesignTokens.pageBackground.opacity(0.92))
                        )
                        .overlay(
                            Circle()
                                .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLikeUpdating || isDeleting)
                    .opacity((isLikeUpdating || isDeleting) ? 0.85 : 1)
                    .padding(10)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(GallerySlot.allCases) { slot in
                        galleryThumbnail(for: slot)
                    }
                }
            }
        }
    }

    private var gallerySkeleton: some View {
        VStack(spacing: 10) {
            SkeletonBlock(height: 320, cornerRadius: 14)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: 72, cornerRadius: 10)
                }
            }
        }
    }

    @ViewBuilder
    private func galleryPage(for slot: GallerySlot) -> some View {
        let imageURL = galleryURL(for: slot)

        ZStack(alignment: .topLeading) {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(ProfileDesignTokens.cardBackground)
                    case .empty:
                        SkeletonBlock(height: 320, cornerRadius: 14)
                    case .failure:
                        galleryPlaceholder(title: slot.shortTitle)
                    @unknown default:
                        galleryPlaceholder(title: slot.shortTitle)
                    }
                }
            } else {
                galleryPlaceholder(title: slot.shortTitle)
            }

            Text(slot.badgeTitle)
                .appTypography(size: 11, weight: .bold)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(ProfileDesignTokens.pageBackground.opacity(0.92))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
                .padding(10)
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
                        AsyncImage(url: imageURL) { phase in
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
                .frame(height: 64)
                .frame(maxWidth: .infinity)
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
            }
        }
        .buttonStyle(.plain)
    }

    private var thumbnailPlaceholder: some View {
        Image(systemName: "photo")
            .appTypography(size: 16, weight: .medium)
            .foregroundStyle(ProfileDesignTokens.sectionTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        switch slot {
        case .generated:
            return detailImageSet.generatedURL
        case .hand:
            return detailImageSet.handURL
        case .reference:
            return detailImageSet.referenceURL
        }
    }

    private var createdAtText: String {
        FittedAIHistoryFormatter.dateTime.string(from: item.createdAt)
    }

    private var selectedShapeOption: AINailShape? {
        guard let shape = item.shape else { return nil }
        return AINailShape(rawValue: shape.rawValue)
    }

    private var extensionModeDisplayText: String? {
        switch item.extensionMode {
        case .extend:
            return "연장"
        case .natural:
            return "미연장"
        case nil:
            return nil
        }
    }

    private var shouldShowSettingsSection: Bool {
        selectedShapeOption != nil || extensionModeDisplayText != nil
    }

    private var footerMetaRow: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            Text(createdAtText)
                .appTypography(size: 11, weight: .medium)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("생성일, \(createdAtText)")

            Button(isDeleting ? "삭제 중..." : "삭제하기") {
                showDeleteConfirmAlert = true
            }
            .buttonStyle(.plain)
            .appTypography(size: 12, weight: .bold)
            .foregroundStyle(ProfileDesignTokens.destructive)
            .disabled(isDeleting)
            .accessibilityLabel("삭제하기")
            .alert("정말 삭제하시겠습니까?", isPresented: $showDeleteConfirmAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제하기", role: .destructive) {
                    Task { await deleteItem() }
                }
            } message: {
                Text("삭제한 이미지는 복구할 수 없어요.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func extensionModeCard(_ text: String) -> some View {
        Text(text)
            .appTypography(size: 12, weight: .bold)
            .foregroundStyle(ProfileDesignTokens.primaryText)
            .lineLimit(1)
            .frame(width: 60, height: 82)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ProfileDesignTokens.aiHistorySummaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ProfileDesignTokens.aiHistorySummaryBorder, lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("연장 옵션, \(text)")
    }

    private func shapeSettingCard(_ shape: AINailShape) -> some View {
        VStack(spacing: 6) {
            shapeSettingPreview(shape)
                .frame(height: 30)

            Text(shape.title)
                .appTypography(size: 11, weight: .bold)
                .foregroundStyle(ProfileDesignTokens.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 52, height: 82)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ProfileDesignTokens.accent, lineWidth: 2)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("네일 모양, \(shape.title)")
    }

    @ViewBuilder
    private func shapeSettingPreview(_ shape: AINailShape) -> some View {
        switch shape {
        case .almond:
            FittedAIDetailAlmondShape()
                .fill(ProfileDesignTokens.aiHistorySummaryBackground)
                .overlay(
                    FittedAIDetailAlmondShape()
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
                .frame(width: 24, height: 30)
        case .square:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(ProfileDesignTokens.aiHistorySummaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
                .frame(width: 24, height: 28)
        case .round:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ProfileDesignTokens.aiHistorySummaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
                .frame(width: 24, height: 28)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .appTypography(size: 12, weight: .bold)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
        )
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
        if hasLoadedDetailImages && !force { return }

        isGalleryLoading = true
        if force {
            galleryErrorMessage = nil
        }
        defer { isGalleryLoading = false }

        do {
            let loaded = try await onLoadDetailImages(item.jobId, item.imageURL)
            detailImageSet = loaded
            hasLoadedDetailImages = true
            galleryErrorMessage = nil
        } catch {
            hasLoadedDetailImages = true
            galleryErrorMessage = "입력 이미지를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        }
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
}

private struct FittedAIDetailAlmondShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(
            cornerRadius: rect.width * 0.5,
            style: .continuous
        ).path(in: rect)
    }
}

private enum FittedAIHistoryFormatter {
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()
}
