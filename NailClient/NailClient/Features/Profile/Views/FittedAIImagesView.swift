//
//  FittedAIImagesView.swift
//  NailClient
//

import SwiftUI

struct FittedAIImagesView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = FittedAIImagesViewModel()
    @State private var selectedItem: FittedAIImagesViewModel.FittedAIImageItem?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                if !viewModel.items.isEmpty {
                    summaryHeader
                }

                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
        .navigationTitle("내가 피팅한 AI 이미지")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadIfNeeded()
        }
        .sheet(item: $selectedItem) { item in
            FittedAIImageDetailSheet(item: item)
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
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.vertical, 12)
            }

            if let errorMessage = viewModel.errorMessage, !viewModel.items.isEmpty {
                inlineErrorState(errorMessage)
            }
        }
    }

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("총 \(viewModel.items.count)개")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)

            Text("원본 \(viewModel.originalCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            Text("수정본 \(viewModel.refinedCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            Spacer(minLength: 8)

            if let latestCreatedAt = viewModel.latestCreatedAt {
                Text("최근 \(FittedAIHistoryFormatter.dateTime.string(from: latestCreatedAt))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                listRow(item)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(currentItemID: item.id)
                        }
                    }

                if index < viewModel.items.count - 1 {
                    Divider()
                        .overlay(ProfileDesignTokens.cardBorder)
                        .padding(.leading, 96)
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { index in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 84, height: 84, cornerRadius: 10)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 120, height: 11, cornerRadius: 6)
                        SkeletonBlock(width: 88, height: 11, cornerRadius: 6)
                        SkeletonBlock(height: 11, cornerRadius: 6)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)

                if index < 5 {
                    Divider()
                        .overlay(ProfileDesignTokens.cardBorder)
                        .padding(.leading, 96)
                }
            }

            Text("피팅한 이미지를 불러오는 중이에요.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(ProfileDesignTokens.sectionTitle)
            Text("아직 피팅한 AI 이미지가 없어요.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.primaryText)
            Text("AI 네일 생성 후 결과가 완료되면 여기에 표시됩니다.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .multilineTextAlignment(.center)

            Button("AI 네일 생성하기") {
                appViewModel.syncSelectedMainTab(.ai)
            }
            .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.destructive)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await viewModel.retry() }
            }
            .font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func inlineErrorState(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.destructive)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Button("다시 시도") {
                Task { await viewModel.retry() }
            }
            .font(.system(size: 12, weight: .bold))
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
        Button {
            selectedItem = item
        } label: {
            HStack(alignment: .top, spacing: 12) {
                thumbnail(item)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(FittedAIHistoryFormatter.dateTime.string(from: item.createdAt))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ProfileDesignTokens.secondaryText)

                        Spacer(minLength: 4)

                        Text("#\(item.shortJobID)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ProfileDesignTokens.secondaryText)
                    }

                    HStack(spacing: 6) {
                        optionChip(item.refinementBadgeText, refined: item.isRefined)

                        if let shapeText = item.shapeText {
                            Text(shapeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ProfileDesignTokens.secondaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(ProfileDesignTokens.aiHistoryPromptBackground)
                                )
                        }
                    }

                    Text(item.promptSummary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.primaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ProfileDesignTokens.sectionTitle)
                    .padding(.top, 2)
            }
            .padding(.vertical, 10)
            .fullRowTapTarget(alignment: .leading)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func thumbnail(_ item: FittedAIImagesViewModel.FittedAIImageItem) -> some View {
        AsyncImage(url: item.imageURL) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty:
                SkeletonBlock(width: 84, height: 84, cornerRadius: 10)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.sectionTitle)
                    .frame(width: 84, height: 84)
                    .background(ProfileDesignTokens.aiHistoryPromptBackground)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func optionChip(_ text: String, refined: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(refined ? ProfileDesignTokens.aiHistoryRefinedBadgeText : ProfileDesignTokens.aiHistoryOriginalBadgeText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(refined ? ProfileDesignTokens.aiHistoryRefinedBadgeBackground : ProfileDesignTokens.aiHistoryOriginalBadgeBackground)
            )
    }
}

private struct FittedAIImageDetailSheet: View {
    struct OptionItem: Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    @Environment(\.dismiss) private var dismiss
    let item: FittedAIImagesViewModel.FittedAIImageItem

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
                                    .font(.system(size: 26, weight: .semibold))
                                Text("이미지를 불러오지 못했어요")
                                    .font(.system(size: 13, weight: .medium))
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
                            .font(.system(size: 14, weight: .medium))
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
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)
                .multilineTextAlignment(.trailing)
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
