//
//  AIDesignSourceSheetView.swift
//  NailClient
//

import SwiftUI
import UIKit
import NailUI

struct AIDesignSourceSheetView: View {
    let previewImage: UIImage?
    let hasReferenceImage: Bool
    let lastSource: AIDesignSourceKind?
    let onSelectPhotoLibrary: () -> Void
    let onRepeatLastSource: () -> Void
    let onClearReference: () -> Void
    let onClose: () -> Void

    private var statusTitle: String? {
        hasReferenceImage ? "디자인 선택됨" : nil
    }

    private var statusDescription: String {
        return hasReferenceImage
            ? "다른 소스로 변경하거나 현재 디자인을 제거할 수 있어요."
            : "사진을 추가해 디자인을 선택해 보세요."
    }

    private var repeatSourceLabel: String {
        guard let lastSource else { return "지난번 방식으로 선택" }

        switch lastSource {
        case .photoLibrary:
            return "지난번처럼 사진에서 선택"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        statusCard
                            .padding(.top, 10)

                        sourceActionCard(
                            title: "사진에서 추가",
                            subtitle: "앨범에서 선택한 뒤 크롭해서 적용해요.",
                            detail: "사진 선택 > 크롭 > 적용",
                            iconName: "photo.on.rectangle.angled",
                            iconColor: AIGenerationDesignTokens.noticeTint,
                            action: onSelectPhotoLibrary
                        )

                        if lastSource != nil {
                            Button(action: onRepeatLastSource) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(repeatSourceLabel)
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AIGenerationDesignTokens.cardSubtleBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(repeatSourceLabel)
                        }

                        if hasReferenceImage {
                            Button(role: .destructive, action: onClearReference) {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("현재 디자인 제거")
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("현재 디자인 제거")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                Divider()

                Button(action: onClose) {
                    Text("닫기")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AIGenerationDesignTokens.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(AIGenerationDesignTokens.cardBackground)
            }
            .background(AIGenerationDesignTokens.screenBackground)
            .navigationTitle("디자인 선택")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AIGenerationDesignTokens.cardSubtleBackground)

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AIGenerationDesignTokens.placeholder)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                if let statusTitle {
                    Text(statusTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AIGenerationDesignTokens.primaryText)
                }
                Text(statusDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AIGenerationDesignTokens.cardSubtleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            hasReferenceImage
                ? "디자인 선택됨. \(statusDescription)"
                : statusDescription
        )
    }

    private func sourceActionCard(
        title: String,
        subtitle: String,
        detail: String,
        iconName: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.14))
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AIGenerationDesignTokens.primaryText)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AIGenerationDesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AIGenerationDesignTokens.secondaryText.opacity(0.85))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AIGenerationDesignTokens.placeholder)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AIGenerationDesignTokens.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AIGenerationDesignTokens.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
