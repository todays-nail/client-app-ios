//
//  FittedAIImagesView.swift
//  NailClient
//

import SwiftUI
import NailUI

@MainActor
struct FittedAIImagesView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: FittedAIImagesViewModel
    @State private var selectedItem: FittedAIImagesViewModel.FittedAIImageItem?
    @State private var gridContainerWidth: CGFloat = FittedAIImagesLayoutMetrics.fallbackContainerWidth
    private let loadsOnTask: Bool
    private let gridSpacing: CGFloat = 1
    private let tileCornerRadius: CGFloat = 0

    @MainActor
    init(loadsOnTask: Bool = true) {
        _viewModel = StateObject(wrappedValue: FittedAIImagesViewModel())
        self.loadsOnTask = loadsOnTask
    }

    @MainActor
    init(
        viewModel: FittedAIImagesViewModel,
        loadsOnTask: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.loadsOnTask = loadsOnTask
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing),
        ]
    }

    private var layoutMetrics: FittedAIImagesLayoutMetrics {
        FittedAIImagesLayoutMetrics(
            containerWidth: gridContainerWidth,
            columnCount: gridColumns.count,
            spacing: gridSpacing
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                filterSegment
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
        .navigationTitle("오늘 네일 AI 피팅 결과")
        .navigationBarTitleDisplayMode(.inline)
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable {
            await viewModel.refresh()
        }
        .task(id: layoutMetrics.thumbnailTargetSize) {
            viewModel.updateThumbnailTargetSize(layoutMetrics.thumbnailTargetSize)
        }
        .task {
            guard loadsOnTask else { return }
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
                        viewModel.prefetchNearFutureThumbnails(currentItemID: item.id)
                        Task {
                            await viewModel.loadMoreIfNeeded(currentItemID: item.id)
                        }
                    }
            }
        }
        .padding(.horizontal, -16)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.width) {
                        let measuredWidth = max(proxy.size.width, 0)
                        guard measuredWidth > 0 else { return }
                        guard abs(gridContainerWidth - measuredWidth) > 0.5 else { return }
                        gridContainerWidth = measuredWidth
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

        return ZStack {
            Button {
                selectedItem = item
            } label: {
                thumbnail(item)
                    .opacity(isDeleting ? 0.55 : 1)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(isDeleting)
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
                    .padding(2)
                    .allowsHitTesting(false)
            } else {
                Button {
                    Task { _ = await viewModel.toggleLike(jobId: item.jobId) }
                } label: {
                    Image(systemName: item.isLiked ? "heart.fill" : "heart")
                        .appTypography(size: 20, weight: .bold)
                        .foregroundStyle(item.isLiked ? ProfileDesignTokens.destructive : ProfileDesignTokens.secondaryText)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isLikeUpdating)
                .opacity(isLikeUpdating ? 0.85 : 1)
                .padding(2)
            }
        }
    }

    private func thumbnail(_ item: FittedAIImagesViewModel.FittedAIImageItem) -> some View {
        NailRemoteImage(
            url: item.imageURL,
            targetSize: layoutMetrics.thumbnailTargetSize,
            resizeMode: .fill
        ) { phase in
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
    }

}

#if DEBUG
private struct FittedAIImagesPreviewHost: View {
    let viewModel: FittedAIImagesViewModel

    var body: some View {
        NavigationStack {
            FittedAIImagesView(viewModel: viewModel, loadsOnTask: false)
                .environmentObject(
                    AppViewModel.preview(
                        route: .home,
                        currentUser: .preview(nickname: "결과 프리뷰"),
                        selectedMainTab: .results
                    )
                )
        }
    }
}

#Preview("목록") {
    FittedAIImagesPreviewHost(viewModel: .previewState())
}

#Preview("빈 상태") {
    FittedAIImagesPreviewHost(
        viewModel: .previewState(
            allItems: [],
            likedItems: [],
            didLoadAll: true,
            didLoadLiked: true
        )
    )
}

#Preview("로딩") {
    FittedAIImagesPreviewHost(
        viewModel: .previewState(
            allItems: [],
            likedItems: [],
            isLoadingAll: true,
            didLoadAll: false,
            didLoadLiked: true
        )
    )
}

#Preview("오류") {
    FittedAIImagesPreviewHost(
        viewModel: .previewState(
            allItems: [],
            likedItems: [],
            allErrorMessage: "이미지 목록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
            didLoadAll: true,
            didLoadLiked: true
        )
    )
}
#endif
