//
//  SocialCircleLoginButton.swift
//  NailClient
//

import SwiftUI
import UIKit

struct SocialCircleLoginButton: View {
    let assetName: String
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: @Sendable () async -> Void

    @State private var isLoading = false

    private let buttonSize: CGFloat = 64
    private let iconSize: CGFloat = 44

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
                if let uiImage = UIImage(named: assetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                } else {
                    Circle()
                        .fill(LoginDesignTokens.borderLight.opacity(0.25))
                        .overlay {
                            Text("?")
                                .appTypography(size: 18, weight: .semibold)
                                .foregroundStyle(LoginDesignTokens.textMuted)
                        }
                }

                if isLoading {
                    Circle()
                        .fill(.black.opacity(0.14))
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

#Preview {
    HStack(spacing: 20) {
        SocialCircleLoginButton(
            assetName: "social_apple_symbol",
            accessibilityLabel: "Apple로 로그인",
            accessibilityIdentifier: "apple_circle_sign_in_button"
        ) {}
        SocialCircleLoginButton(
            assetName: "social_kakao_symbol",
            accessibilityLabel: "카카오로 로그인",
            accessibilityIdentifier: "kakao_circle_sign_in_button"
        ) {}
        SocialCircleLoginButton(
            assetName: "social_google_symbol",
            accessibilityLabel: "Google로 로그인",
            accessibilityIdentifier: "google_circle_sign_in_button"
        ) {}
    }
    .padding()
}
