//
//  AINailGenerationResultView.swift
//  NailClient
//

import SwiftUI

struct AINailGenerationResultView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AINailGenerationViewModel

    @State private var showRefineSheet: Bool = false
    @State private var refinementPrompt: String = ""
    @State private var refinementShape: AINailShape = .almond

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                resultImageSection
                summarySection
                refineHintSection
            }
            .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .background(AIGenerationDesignTokens.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .navigationTitle("생성 결과")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRefineSheet) {
            refineSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var resultImageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 생성 결과")
                .font(.system(AIGenerationDesignTokens.sectionTitleStyle, weight: .bold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)

            if let resultImageURL = viewModel.resultImageURL {
                AsyncImage(url: resultImageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28, weight: .semibold))
                            Text("결과 이미지를 불러오지 못했습니다.")
                                .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .medium))
                        }
                        .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 220)
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AIGenerationDesignTokens.cardCornerRadius, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
            }

            if viewModel.isSubmitting {
                Text(viewModel.statusMessage)
                    .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard(title: "선택한 네일 모양", value: viewModel.selectedShape.title)
            summaryCard(title: "추가 요청사항", value: promptSummary)
        }
    }

    private var refineHintSection: some View {
        Group {
            if viewModel.canRefine {
                summaryCard(title: "재편집", value: "현재 결과에 대해 프롬프트 기반으로 1회 추가 수정이 가능합니다.")
            } else {
                summaryCard(title: "재편집", value: "이 결과는 재편집을 이미 사용했거나 지원하지 않는 상태입니다.")
            }
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.secondaryText)
            Text(value)
                .font(.system(AIGenerationDesignTokens.bodyStyle, weight: .medium))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AIGenerationDesignTokens.cardSubtleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
        )
    }

    private var bottomButton: some View {
        VStack(spacing: 10) {
            Button {
                refinementShape = viewModel.selectedShape
                refinementPrompt = ""
                showRefineSheet = true
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(viewModel.isSubmitting ? "수정 생성 중..." : "한 번 더 수정하기")
                        .font(.system(AIGenerationDesignTokens.ctaStyle, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            viewModel.canRefine && !viewModel.isSubmitting
                                ? AIGenerationDesignTokens.accent
                                : AIGenerationDesignTokens.placeholder
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRefine || viewModel.isSubmitting || viewModel.currentJobId == nil)

            Button {
                dismiss()
            } label: {
                Text("생성 화면으로 돌아가기")
                    .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AIGenerationDesignTokens.cardSubtleBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AIGenerationDesignTokens.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AIGenerationDesignTokens.border)
                .frame(height: 1)
        }
    }

    private var refineSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("현재 생성 결과를 기준으로 프롬프트를 한 번 더 적용합니다.")
                    .font(.system(AIGenerationDesignTokens.secondaryBodyStyle, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)

                Text("네일 모양")
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)

                Picker("네일 모양", selection: $refinementShape) {
                    ForEach(AINailShape.allCases) { shape in
                        Text(shape.title).tag(shape)
                    }
                }
                .pickerStyle(.segmented)

                Text("수정 프롬프트")
                    .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)

                TextEditor(text: $refinementPrompt)
                    .font(.system(AIGenerationDesignTokens.bodyStyle, weight: .medium))
                    .frame(minHeight: 140)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AIGenerationDesignTokens.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                            )
                    )

                HStack {
                    Spacer()
                    Text("\(refinementPrompt.count)/\(AINailGenerationViewModel.maxRefinementPromptLength)")
                        .font(.system(AIGenerationDesignTokens.metaStyle, weight: .semibold))
                        .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(AIGenerationDesignTokens.metaStyle, weight: .medium))
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
            .padding(.top, 16)
            .navigationTitle("한 번 더 수정하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        showRefineSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSubmitting ? "생성 중..." : "수정 생성") {
                        Task {
                            guard let sourceJobId = viewModel.currentJobId else { return }
                            let succeeded = await viewModel.submitRefinement(
                                sourceJobId: sourceJobId,
                                shape: refinementShape,
                                prompt: refinementPrompt
                            )
                            if succeeded {
                                showRefineSheet = false
                            }
                        }
                    }
                    .disabled(!canSubmitRefinement || viewModel.isSubmitting || viewModel.currentJobId == nil)
                }
            }
        }
    }

    private var promptSummary: String {
        let trimmed = viewModel.latestPromptSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "입력 없음" : trimmed
    }

    private var canSubmitRefinement: Bool {
        let trimmed = refinementPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= AINailGenerationViewModel.maxRefinementPromptLength
    }
}

#Preview {
    NavigationStack {
        AINailGenerationResultView(viewModel: AINailGenerationViewModel())
    }
}
