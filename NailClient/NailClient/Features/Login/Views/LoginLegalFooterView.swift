//
//  LoginLegalFooterView.swift
//  NailClient
//
//  Created by Codex.
//

import SwiftUI

struct LoginLegalFooterView: View {
    let onTapTerms: () -> Void
    let onTapPrivacy: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("로그인 시 Today's Nail의")

            HStack(spacing: 4) {
                UnderlinedTextButton(title: "이용약관", action: onTapTerms)
                Text("및")
                UnderlinedTextButton(title: "개인정보처리방침", action: onTapPrivacy)
                Text("에")
            }
            .fixedSize(horizontal: false, vertical: true)

            Text("동의하게 됩니다.")
        }
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(LoginDesignTokens.textMuted.opacity(0.5))
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .padding(.horizontal, 16)
        .padding(.top, 32)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
    }
}

private struct UnderlinedTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.bottom, 1)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LoginDesignTokens.textMuted.opacity(0.3))
                        .frame(height: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LoginLegalFooterView(
        onTapTerms: {},
        onTapPrivacy: {}
    )
    .background(LoginBackgroundView())
}

