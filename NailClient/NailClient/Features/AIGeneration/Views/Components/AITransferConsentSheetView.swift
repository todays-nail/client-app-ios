//
//  AITransferConsentSheetView.swift
//  NailClient
//

import SwiftUI

struct AITransferConsentSheetView: View {
    let onDecline: () -> Void
    let onApprove: () -> Void
    var onOpenPrivacyPolicy: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    VStack(spacing: 10) {
                        consentRow(
                            icon: "sparkles",
                            title: "전송 목적",
                            description: "AI 네일 생성 결과 제공 및 요청 처리"
                        )
                        consentRow(
                            icon: "photo.on.rectangle.angled",
                            title: "전송 데이터",
                            description: "손 사진, 디자인 사진, 생성 요청 관련 설정 값"
                        )
                        consentRow(
                            icon: "network",
                            title: "전송 대상",
                            description: "OpenAI(이미지 생성 처리), Supabase(저장/전달 처리)"
                        )
                    }

                    if let onOpenPrivacyPolicy {
                        Button {
                            onOpenPrivacyPolicy()
                        } label: {
                            Text("개인정보처리방침 보기")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(AIGenerationDesignTokens.secondaryText.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AIGenerationDesignTokens.cardBackground)
            .safeAreaInset(edge: .bottom) {
                actionSection
            }
            .navigationTitle("AI 데이터 전송 동의")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.accent)

                Text("생성 전에 전송 정보를 확인해 주세요.")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AIGenerationDesignTokens.primaryText)
            }

            Text("동의 후에만 AI 생성 요청이 전송되며, 설정에서 철회할 수 있어요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AIGenerationDesignTokens.secondaryText)
        }
    }

    private func consentRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AIGenerationDesignTokens.accent)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(AIGenerationDesignTokens.cardSubtleBackground)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AIGenerationDesignTokens.primaryText)
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 40, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AIGenerationDesignTokens.cardSubtleBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
        )
    }

    private var actionSection: some View {
        VStack(spacing: 8) {
            liquidPrimaryConsentButton

            Button("동의 안 함") {
                onDecline()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AIGenerationDesignTokens.secondaryText.opacity(0.78))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var liquidPrimaryConsentButton: some View {
        Button("동의하고 생성") {
            onApprove()
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black)
        )
        .buttonStyle(.plain)
    }
}

#if DEBUG
private struct AITransferConsentSheetPreviewHost: View {
    @State private var isPresented = true

    var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                AITransferConsentSheetView(
                    onDecline: { isPresented = false },
                    onApprove: { isPresented = false },
                    onOpenPrivacyPolicy: {}
                )
            }
    }
}

#Preview("AI 데이터 전송 동의 시트") {
    AITransferConsentSheetPreviewHost()
}
#endif
