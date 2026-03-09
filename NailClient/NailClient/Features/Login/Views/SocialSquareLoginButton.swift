//
//  SocialSquareLoginButton.swift
//  NailClient
//

import SwiftUI
import UIKit
import NailUI

struct SocialSquareLoginButton: View {
    let assetName: String
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () async -> Void

    @State private var isLoading = false

    private let buttonSize: CGFloat = 56
    private let cornerRadius: CGFloat = 12

    var body: some View {
        Button {
            guard !isLoading else { return }
            isLoading = true
            Task {
                await action()
                isLoading = false
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LoginDesignTokens.borderLight.opacity(0.15))

                if let uiImage = UIImage(named: assetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LoginDesignTokens.borderLight.opacity(0.35))
                }

                if isLoading {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.black.opacity(0.12))
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .frame(width: buttonSize, height: buttonSize)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

#Preview {
    HStack(spacing: 16) {
        SocialSquareLoginButton(
            assetName: "social_apple_square",
            accessibilityLabel: "Apple로 로그인",
            accessibilityIdentifier: "apple_sign_in_button"
        ) {}

        SocialSquareLoginButton(
            assetName: "social_kakao_square",
            accessibilityLabel: "카카오로 로그인",
            accessibilityIdentifier: "kakao_sign_in_button"
        ) {}

        SocialSquareLoginButton(
            assetName: "social_google_square",
            accessibilityLabel: "Google로 로그인",
            accessibilityIdentifier: "google_sign_in_button"
        ) {}
    }
    .padding()
}
