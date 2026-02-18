//
//  QuoteRequestListView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct QuoteRequestListView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = QuoteRequestListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("견적 요청 목록을 불러오는 중이에요.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.secondaryText)
                    Text("아직 생성된 견적 요청이 없어요.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ProfileDesignTokens.primaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                QuoteResponseListView(quoteRequestID: item.id)
                                    .environmentObject(appViewModel)
                            } label: {
                                requestCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
        .navigationTitle("내 견적 요청")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadIfNeeded()
        }
        .alert(
            "불러오기 실패",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "견적 요청을 불러오지 못했어요.")
        }
    }

    private func requestCard(_ item: QuoteRequestListViewModel.QuoteRequestRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.targetModeText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ProfileDesignTokens.accent)
                Spacer(minLength: 8)
                Text(item.statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(statusColor(item.status))
                    )
            }

            Text("희망일: \(item.preferredDate)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            Text(item.requestNote)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.primaryText)
                .lineLimit(2)

            HStack {
                Text(item.responseProgressText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
                Spacer(minLength: 8)
                Text(item.createdAtText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
            }
        }
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

    private func statusColor(_ status: QuoteRequestStatus) -> Color {
        switch status {
        case .open:
            return ProfileDesignTokens.accent
        case .selected:
            return .green
        case .closed:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        QuoteRequestListView()
            .environmentObject(AppViewModel())
    }
}
