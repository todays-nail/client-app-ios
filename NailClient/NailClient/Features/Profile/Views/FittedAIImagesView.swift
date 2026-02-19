//
//  FittedAIImagesView.swift
//  NailClient
//

import SwiftUI

struct FittedAIImagesView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = FittedAIImagesViewModel()
    @State private var selectedItem: FittedAIImagesViewModel.FittedAIImageItem?
    private let gridSpacing: CGFloat = 8
    private let tileCornerRadius: CGFloat = 12
    private let defaultShapeChipText: String = "기본 모양"

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                filterSegment
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
        .navigationTitle("오늘 네일 AI 피팅 결과")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadIfNeeded()
        }
        .sheet(item: $selectedItem) { item in
            FittedAIImageDetailSheet(
                item: item,
                onLoadDetailImages: { jobId, fallbackGeneratedURL in
                    try await viewModel.fetchDetailImageSet(
                        jobId: jobId,
                        fallbackGeneratedURL: fallbackGeneratedURL
                    )
                },
                onToggleLike: { nextLikeState in
                    await viewModel.setLike(jobId: item.jobId, isLiked: nextLikeState)
                },
                onDelete: {
                    await viewModel.delete(jobId: item.jobId)
                }
            )
        }
    }

    private var filterSegment: some View {
        Picker(
            "결과 필터",
            selection: Binding(
                get: { viewModel.selectedFilter },
                set: { newValue in
                    Task { await viewModel.setFilter(newValue) }
                }
            )
        ) {
            ForEach(FittedAIImagesViewModel.ListFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            loadingState
        } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
            errorState(errorMessage)
        } else if viewModel.shouldShowEmptyState {
            emptyState(for: viewModel.selectedFilter)
        } else {
            listContent

            if viewModel.isLoadingMore {
                ProgressView("더 불러오는 중...")
                    .appTypography(size: 13, weight: .semibold)
                    .padding(.vertical, 12)
            }

            if let errorMessage = viewModel.errorMessage, !viewModel.items.isEmpty {
                inlineErrorState(errorMessage)
            }
        }
    }

    private var listContent: some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(viewModel.items) { item in
                listRow(item)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(currentItemID: item.id)
                        }
                    }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
                .tint(ProfileDesignTokens.accent)

            Text("불러오는 중...")
                .appTypography(size: 13, weight: .semibold)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func emptyState(for filter: FittedAIImagesViewModel.ListFilter) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .appTypography(size: 30, weight: .regular)
                .foregroundStyle(ProfileDesignTokens.sectionTitle)

            if filter == .liked {
                Text("좋아요한 AI 결과가 없어요.")
                    .appTypography(size: 15, weight: .semibold)
                    .foregroundStyle(ProfileDesignTokens.primaryText)
                Text("원하는 결과에 하트를 눌러 모아보세요.")
                    .appTypography(size: 13, weight: .medium)
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
                    .multilineTextAlignment(.center)

                Button("전체 결과 보기") {
                    Task { await viewModel.setFilter(.all) }
                }
                .appTypography(size: 13, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(ProfileDesignTokens.accent)
                )
                .padding(.top, 2)
            } else {
                Text("아직 피팅한 AI 이미지가 없어요.")
                    .appTypography(size: 15, weight: .semibold)
                    .foregroundStyle(ProfileDesignTokens.primaryText)
                Text("AI 네일 생성 후 결과가 완료되면 여기에 표시됩니다.")
                    .appTypography(size: 13, weight: .medium)
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
                    .multilineTextAlignment(.center)

                Button("AI 네일 생성하기") {
                    appViewModel.syncSelectedMainTab(.ai)
                }
                .appTypography(size: 13, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(ProfileDesignTokens.accent)
                )
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .appTypography(size: 22, weight: .semibold)
                .foregroundStyle(ProfileDesignTokens.destructive)
            Text(message)
                .appTypography(size: 14, weight: .medium)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await viewModel.retry() }
            }
            .appTypography(size: 14, weight: .semibold)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func inlineErrorState(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .appTypography(size: 14, weight: .semibold)
                .foregroundStyle(ProfileDesignTokens.destructive)

            Text(message)
                .appTypography(size: 12, weight: .medium)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Button("다시 시도") {
                Task { await viewModel.retry() }
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

    private func listRow(_ item: FittedAIImagesViewModel.FittedAIImageItem) -> some View {
        let isDeleting = viewModel.isDeleting(jobId: item.jobId)
        let isLikeUpdating = viewModel.isLikeUpdating(jobId: item.jobId)

        return ZStack(alignment: .topLeading) {
            Button {
                selectedItem = item
            } label: {
                thumbnail(item)
                    .opacity(isDeleting ? 0.55 : 1)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(isDeleting)

            shapeChip(for: item)
                .padding(6)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if isDeleting {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(ProfileDesignTokens.pageBackground.opacity(0.92))
                    )
                    .padding(6)
                    .allowsHitTesting(false)
            } else {
                Button {
                    Task { _ = await viewModel.toggleLike(jobId: item.jobId) }
                } label: {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                        .appTypography(size: 12, weight: .bold)
                        .foregroundStyle(item.isLiked ? ProfileDesignTokens.destructive : ProfileDesignTokens.secondaryText)
                        .frame(width: 28, height: 28)
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
                .disabled(isLikeUpdating)
                .opacity(isLikeUpdating ? 0.5 : 1)
                .padding(6)
            }
        }
    }

    private func shapeChip(for item: FittedAIImagesViewModel.FittedAIImageItem) -> some View {
        Text(shapeChipText(for: item))
            .appTypography(size: 10, weight: .bold)
            .foregroundStyle(ProfileDesignTokens.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(ProfileDesignTokens.aiHistoryPromptBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
            )
    }

    private func thumbnail(_ item: FittedAIImagesViewModel.FittedAIImageItem) -> some View {
        AsyncImage(url: item.imageURL) { phase in
            ZStack {
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ZStack {
                        ProfileDesignTokens.aiHistoryPromptBackground
                        ProgressView()
                            .controlSize(.small)
                            .tint(ProfileDesignTokens.accent)
                    }
                case .failure:
                    Image(systemName: "photo")
                        .appTypography(size: 20, weight: .medium)
                        .foregroundStyle(ProfileDesignTokens.sectionTitle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ProfileDesignTokens.aiHistoryPromptBackground)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(ProfileDesignTokens.aiHistoryPromptBackground)
        .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
        )
    }

    private func shapeChipText(for item: FittedAIImagesViewModel.FittedAIImageItem) -> String {
        let normalized = item.shapeText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            return defaultShapeChipText
        }
        return normalized
    }
}

private struct FittedAIImageDetailSheet: View {
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

    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var isDeleting: Bool = false
    @State private var isLikeUpdating: Bool = false
    @State private var isLiked: Bool
    @State private var selectedGalleryIndex: Int = 0
    @State private var detailImageSet: FittedAIImagesViewModel.DetailImageSet
    @State private var isGalleryLoading: Bool = false
    @State private var hasLoadedDetailImages: Bool = false
    @State private var galleryErrorMessage: String?
    @State private var activeAlert: AlertMessage?

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

                    sectionCard(title: "빠른 작업") {
                        VStack(spacing: 10) {
                            Button {
                                isDeleteConfirmationPresented = true
                            } label: {
                                HStack(spacing: 8) {
                                    if isDeleting {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(ProfileDesignTokens.destructive)
                                    }
                                    Text(isDeleting ? "삭제 중..." : "삭제")
                                        .appTypography(size: 14, weight: .semibold)
                                }
                                .foregroundStyle(ProfileDesignTokens.destructive)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(ProfileDesignTokens.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(ProfileDesignTokens.destructive.opacity(0.45), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isDeleting)
                        }
                    }

                    sectionCard(title: "기본 정보") {
                        VStack(spacing: 10) {
                            optionRow(title: "생성일", value: FittedAIHistoryFormatter.dateTime.string(from: item.createdAt))
                            optionRow(title: "네일 모양", value: item.shapeText ?? "선택 안 함")
                        }
                    }

                    if shouldShowPrompt {
                        sectionCard(title: "프롬프트") {
                            Text(item.promptSummary)
                                .appTypography(size: 14, weight: .medium)
                                .foregroundStyle(ProfileDesignTokens.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "이 이미지를 삭제할까요?",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    Task { await deleteItem() }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제 후 복구할 수 없어요.")
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
                        Group {
                            if isLikeUpdating {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(ProfileDesignTokens.accent)
                            } else {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .appTypography(size: 12, weight: .bold)
                                    .foregroundStyle(isLiked ? ProfileDesignTokens.destructive : ProfileDesignTokens.secondaryText)
                            }
                        }
                        .frame(width: 30, height: 30)
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
                    .disabled(isLikeUpdating)
                    .opacity(isLikeUpdating ? 0.55 : 1)
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

    private var shouldShowPrompt: Bool {
        let prompt = item.promptSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return !prompt.isEmpty && prompt != "프롬프트 입력 없음"
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

    private func optionRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .appTypography(size: 12, weight: .semibold)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .appTypography(size: 12, weight: .bold)
                .foregroundStyle(ProfileDesignTokens.primaryText)
                .multilineTextAlignment(.trailing)
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
        isLikeUpdating = true
        defer { isLikeUpdating = false }

        let nextLikeState = !isLiked
        let succeeded = await onToggleLike(nextLikeState)
        if succeeded {
            isLiked = nextLikeState
        } else {
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

private enum FittedAIHistoryFormatter {
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        FittedAIImagesView()
            .environmentObject(AppViewModel())
    }
}
