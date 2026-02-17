//
//  FittedAIImagesView.swift
//  NailClient
//

import SwiftUI

struct FittedAIImagesView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = FittedAIImagesViewModel()

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    loadingState
                } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                    errorState(errorMessage)
                } else if viewModel.shouldShowEmptyState {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.items) { item in
                            cell(item)
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(currentItemID: item.id)
                                    }
                                }
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 12)
                    }

                    if let errorMessage = viewModel.errorMessage, !viewModel.items.isEmpty {
                        VStack(spacing: 8) {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ProfileDesignTokens.secondaryText)
                                .multilineTextAlignment(.center)
                            Button("다시 시도") {
                                Task { await viewModel.retry() }
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.top, 8)
                    }
                }
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
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("피팅한 이미지를 불러오는 중이에요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
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

    private func cell(_ item: FittedAIImagesViewModel.FittedAIImageItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: item.imageURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .background(ProfileDesignTokens.cardBackground)
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.sectionTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .background(ProfileDesignTokens.cardBackground)
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(Self.dateFormatter.string(from: item.createdAt))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
                .lineLimit(1)

            if let shapeText = item.shapeText {
                Text(shapeText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ProfileDesignTokens.accent)
                    .lineLimit(1)
            }

            if !item.promptText.isEmpty {
                Text(item.promptText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.primaryText)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

#Preview {
    NavigationStack {
        FittedAIImagesView()
            .environmentObject(AppViewModel())
    }
}
