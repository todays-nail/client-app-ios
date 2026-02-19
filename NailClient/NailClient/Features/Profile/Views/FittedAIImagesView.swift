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
                onDelete: {
                    await viewModel.delete(jobId: item.jobId)
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            loadingState
        } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
            errorState(errorMessage)
        } else if viewModel.shouldShowEmptyState {
            emptyState
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
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(0..<9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                    .fill(FeedDesignTokens.skeletonBase)
                    .shimmer()
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .appTypography(size: 30, weight: .regular)
                .foregroundStyle(ProfileDesignTokens.sectionTitle)
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

        return Button {
            selectedItem = item
        } label: {
            thumbnail(item)
                .overlay(alignment: .topLeading) {
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
                                    .fill(ProfileDesignTokens.pageBackground.opacity(0.9))
                            )
                            .padding(6)
                            .allowsHitTesting(false)
                    }
                }
                .opacity(isDeleting ? 0.55 : 1)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isDeleting)
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
                    RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                        .fill(FeedDesignTokens.skeletonBase)
                        .shimmer()
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
    struct OptionItem: Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    struct AlertMessage: Identifiable {
        let id: String
        let title: String
        let message: String
    }

    @Environment(\.dismiss) private var dismiss
    let item: FittedAIImagesViewModel.FittedAIImageItem
    let onDelete: @MainActor () async -> Bool

    @State private var isDeleteConfirmationPresented: Bool = false
    @State private var isDeleting: Bool = false
    @State private var activeAlert: AlertMessage?

    private var selectedOptions: [OptionItem] {
        [
            .init(title: "네일 모양", value: item.shapeText ?? "선택 안 함"),
            .init(title: "결과 유형", value: item.isRefined ? "수정본" : "원본"),
            .init(title: "수정 차수", value: item.isRefined ? "\(max(1, item.refinementTurn))차" : "해당 없음"),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncImage(url: item.imageURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        case .empty:
                            SkeletonBlock(height: 320, cornerRadius: 14)
                                .frame(maxWidth: .infinity)
                        case .failure:
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .appTypography(size: 26, weight: .semibold)
                                Text("이미지를 불러오지 못했어요")
                                    .appTypography(size: 13, weight: .medium)
                            }
                            .foregroundStyle(ProfileDesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 260)
                            .background(ProfileDesignTokens.aiHistoryPromptBackground)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                    )

                    sectionCard(title: "선택 옵션") {
                        VStack(spacing: 10) {
                            ForEach(selectedOptions) { option in
                                optionRow(title: option.title, value: option.value)
                            }
                        }
                    }

                    sectionCard(title: "프롬프트") {
                        Text(item.promptSummary)
                            .appTypography(size: 14, weight: .medium)
                            .foregroundStyle(ProfileDesignTokens.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    sectionCard(title: "생성 정보") {
                        VStack(spacing: 10) {
                            optionRow(title: "생성일", value: FittedAIHistoryFormatter.dateTime.string(from: item.createdAt))
                            optionRow(title: "현재 Job", value: item.shortJobID)
                            if let parentJobId = item.parentJobId {
                                optionRow(title: "원본 Job", value: String(parentJobId.uuidString.prefix(8)))
                            }
                        }
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 22)
            }
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationTitle("피팅 이미지 상세")
            .navigationBarTitleDisplayMode(.inline)
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
