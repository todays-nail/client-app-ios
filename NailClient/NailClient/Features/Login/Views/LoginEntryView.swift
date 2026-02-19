//
//  LoginEntryView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct LoginEntryView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = LoginEntryViewModel()

    var body: some View {
        ZStack {
            LoginBackgroundView()

            GeometryReader { proxy in
                let topSpacing = clamped(proxy.safeAreaInsets.top + (proxy.size.height * 1), min: 12, max: 160)
                // SNS 섹션과 로고 영역 간격을 더 촘촘하게 유지한다.
                let brandToActionSpacing = clamped(proxy.size.height * 0.4, min: 4, max: 150)
                let bottomSpacing = clamped(proxy.safeAreaInsets.bottom + (proxy.size.height * 0.08), min: 12, max: 48)

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: topSpacing)

                    VStack(spacing: 0) {
                        branding
                            .padding(.top, 10)
                        Color.clear
                            .frame(height: brandToActionSpacing)
                        actions
                    }
                    .frame(maxWidth: LoginDesignTokens.maxContentWidth)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: bottomSpacing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(24)
                .clipped()
            }
        }
        .onChange(of: appViewModel.errorMessage) { _, newValue in
            guard let newValue else { return }
            viewModel.presentError(newValue)
        }
        .task {
            await appViewModel.refreshSocialLoginUIVariant()
        }
        .alert(item: $viewModel.activeAlert) { alert in
            switch alert {
            case .error(let message):
                return Alert(
                    title: Text("오류"),
                    message: Text(message),
                    dismissButton: .cancel(Text("확인")) { appViewModel.errorMessage = nil }
                )
            }
        }
    }

    private var branding: some View {
        VStack(spacing: 0) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 118)
                .padding(.bottom, 36)

            Text("오늘 네일")
                .appTypography(size: 28, weight: .semibold)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : LoginDesignTokens.textMain)
                .tracking(-0.3)

            Text("고민말고, AI로 오늘 네일")
                .appTypography(size: 16, weight: .regular)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : LoginDesignTokens.textMuted.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .tracking(-0.2)
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        VStack(spacing: 16) {
            socialSectionHeader
            socialButtons
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var socialButtons: some View {
        switch appViewModel.socialLoginUIVariant {
        case .circular:
            circularSocialButtons
        case .official:
            officialSocialButtons
        }
    }

    private var circularSocialButtons: some View {
        HStack(spacing: 20) {
            SocialCircleLoginButton(
                assetName: "social_apple_symbol",
                accessibilityLabel: "Apple로 로그인",
                accessibilityIdentifier: "apple_circle_sign_in_button"
            ) {
                await appViewModel.signInWithApple()
            }

            SocialCircleLoginButton(
                assetName: "social_kakao_symbol",
                accessibilityLabel: "카카오로 로그인",
                accessibilityIdentifier: "kakao_circle_sign_in_button"
            ) {
                await appViewModel.signInWithKakao()
            }

            SocialCircleLoginButton(
                assetName: "social_google_symbol",
                accessibilityLabel: "Google로 로그인",
                accessibilityIdentifier: "google_circle_sign_in_button"
            ) {
                await appViewModel.signInWithGoogle()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var officialSocialButtons: some View {
        VStack(spacing: 12) {
            AppleLoginButton {
                await appViewModel.signInWithApple()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)

            KakaoLoginImageButton(assetName: "kakao_login_large_wide") {
                await appViewModel.signInWithKakao()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            GoogleLoginButton {
                await appViewModel.signInWithGoogle()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
    }

    private var socialSectionHeader: some View {
        HStack(spacing: 12) {
            sectionDivider

            Text("SNS 계정으로 이용하기")
                .appTypography(size: 16, weight: .semibold)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : LoginDesignTokens.textMuted)
                .fixedSize(horizontal: true, vertical: true)

            sectionDivider
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(LoginDesignTokens.borderLight.opacity(colorScheme == .dark ? 0.42 : 0.85))
            .frame(height: 1)
    }

    private func clamped(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

#Preview {
    LoginEntryView()
        .environmentObject(AppViewModel())
}
