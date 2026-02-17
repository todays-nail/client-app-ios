//
//  LikedDesignsView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct LikedDesignsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = LikedDesignsViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    FeedListSkeletonView()
                        .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                        .padding(.top, 10)
                } else if viewModel.items.isEmpty {
                    emptyStateView
                        .padding(.horizontal, 16)
                        .padding(.top, 48)
                } else {
                    FeedSectionView(
                        items: viewModel.items,
                        onToggleLike: viewModel.toggleLike,
                        onApplyLikeState: { itemID, isLiked, likeCount in
                            viewModel.applyLikeStateFromDetail(for: itemID, isLiked: isLiked, likeCount: likeCount)
                        },
                        onItemAppear: { itemID in
                            Task {
                                await viewModel.loadMoreIfNeeded(currentItemID: itemID)
                            }
                        }
                    )
                    .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                    .padding(.top, 10)

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        inlineErrorView(message: errorMessage)
                            .padding(.horizontal, FeedDesignTokens.horizontalPadding)
                            .padding(.top, 12)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(FeedDesignTokens.accent)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                }
            }
            .padding(.bottom, 18)
        }
        .background(FeedDesignTokens.screenBackground.ignoresSafeArea())
        .navigationTitle("찜한 디자인")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadInitialFeed(force: true)
        }
        .alert("좋아요 반영 실패", isPresented: likeErrorAlertBinding) {
            Button("확인", role: .cancel) {
                viewModel.likeErrorMessage = nil
            }
        } message: {
            Text(viewModel.likeErrorMessage ?? "좋아요 반영에 실패했어요.")
        }
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadInitialFeedIfNeeded()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.slash")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.sectionTitle)

            Text("아직 찜한 디자인이 없어요")
                .font(.headline)
                .foregroundStyle(ProfileDesignTokens.primaryText)

            Text("피드에서 하트를 눌러 디자인을 저장해 보세요.")
                .font(.subheadline)
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                inlineErrorView(message: errorMessage)
            } else {
                Button("다시 불러오기") {
                    Task {
                        await viewModel.loadInitialFeed(force: true)
                    }
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(FeedDesignTokens.accent)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func inlineErrorView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)

            Text("목록을 불러오지 못했어요")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Button("재시도") {
                Task {
                    await viewModel.loadInitialFeed(force: true)
                }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHint(message)
    }

    private var likeErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { (viewModel.likeErrorMessage?.isEmpty == false) },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.likeErrorMessage = nil
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        LikedDesignsView()
            .environmentObject(AppViewModel())
    }
}
