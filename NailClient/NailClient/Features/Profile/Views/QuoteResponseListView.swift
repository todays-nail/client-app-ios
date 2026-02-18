//
//  QuoteResponseListView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct QuoteResponseListView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: QuoteResponseListViewModel

    init(quoteRequestID: UUID) {
        _viewModel = StateObject(wrappedValue: QuoteResponseListViewModel(quoteRequestID: quoteRequestID))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.responses.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("응답 목록을 불러오는 중이에요.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if let requestSummary = viewModel.requestSummary {
                            requestSummaryCard(requestSummary)
                        }

                        if let imageSummary = viewModel.imageSummary {
                            imageSection(imageSummary)
                        }

                        Text("샵 응답")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ProfileDesignTokens.primaryText)

                        if viewModel.responses.isEmpty {
                            Text("아직 도착한 응답이 없어요.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ProfileDesignTokens.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            ForEach(viewModel.responses) { response in
                                responseCard(response)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
        .navigationTitle("견적 응답 확인")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadIfNeeded()
        }
        .alert(
            "오류",
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
            Text(viewModel.errorMessage ?? "요청 처리 중 오류가 발생했어요.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let toastMessage = viewModel.toastMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Button("닫기") {
                        viewModel.dismissToast()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(ProfileDesignTokens.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }

    private func requestSummaryCard(_ summary: QuoteResponseListViewModel.RequestSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.targetModeText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ProfileDesignTokens.accent)
                Spacer(minLength: 8)
                Text(summary.statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(statusColor(summary.status))
                    )
            }

            Text("희망일: \(summary.preferredDate)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            Text(summary.requestNote)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.primaryText)
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

    private func imageSection(_ summary: QuoteResponseListViewModel.ImageSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("첨부 이미지")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    imageCell(urlString: summary.userHandImageURL, title: "사용자 손 사진")
                    imageCell(urlString: summary.aiInputHandImageURL, title: "AI 입력 손 사진")
                    imageCell(urlString: summary.aiResultImageURL, title: "AI 결과")
                }
            }
        }
    }

    private func imageCell(urlString: String?, title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: urlString.flatMap(URL.init(string:))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray.opacity(0.18)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(ProfileDesignTokens.secondaryText)
                        }
                case .empty:
                    ProgressView()
                @unknown default:
                    Color.gray.opacity(0.18)
                }
            }
            .frame(width: 130, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)
        }
    }

    private func responseCard(_ response: QuoteResponseListViewModel.ResponseRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(response.shopName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ProfileDesignTokens.primaryText)
                    Text(response.shopAddress)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(response.targetStatusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
            }

            Text("요청시각: \(response.sentAtText)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ProfileDesignTokens.secondaryText)

            Text("최종가: \(response.finalPriceText)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)

            if response.hasResponse {
                Text("변동 항목: \(response.changeItemsText)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)

                if let memo = response.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.primaryText)
                }
            }

            if viewModel.canSelectTarget(response.id) || viewModel.selectingTargetIDs.contains(response.id) {
                Button {
                    Task { await viewModel.selectTarget(response.id) }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.selectingTargetIDs.contains(response.id) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(viewModel.selectingTargetIDs.contains(response.id) ? "선택 중..." : "이 샵 선택")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ProfileDesignTokens.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectingTargetIDs.contains(response.id))
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
        QuoteResponseListView(quoteRequestID: UUID())
            .environmentObject(AppViewModel())
    }
}
