//
//  AINailGenerationResultView.swift
//  NailClient
//

import SwiftUI

struct AINailGenerationResultView: View {
    @Environment(\.dismiss) private var dismiss

    let resultImageURL: URL
    let selectedShapeTitle: String
    let promptSummary: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                resultImageSection
                summarySection
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
    }

    private var resultImageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 생성 결과")
                .font(.system(AIGenerationDesignTokens.sectionTitleStyle, weight: .bold))
                .foregroundStyle(AIGenerationDesignTokens.primaryText)

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
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard(title: "선택한 네일 모양", value: selectedShapeTitle)
            summaryCard(title: "추가 요청사항", value: promptSummary.isEmpty ? "입력 없음" : promptSummary)
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
        Button {
            dismiss()
        } label: {
            Text("다시 생성하기")
                .font(.system(AIGenerationDesignTokens.ctaStyle, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AIGenerationDesignTokens.accent)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AIGenerationDesignTokens.pageHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AIGenerationDesignTokens.border)
                .frame(height: 1)
        }
    }
}

#Preview {
    NavigationStack {
        AINailGenerationResultView(
            resultImageURL: URL(string: "https://picsum.photos/800/1200")!,
            selectedShapeTitle: "아몬드",
            promptSummary: "#심플하게 #데일리무드"
        )
    }
}
