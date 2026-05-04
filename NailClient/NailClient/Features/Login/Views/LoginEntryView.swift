//
//  LoginEntryView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI
import NailUI

struct LoginEntryView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = LoginEntryViewModel()
#if DEBUG
    @State private var devAccountKey = "default"
    @State private var devSecret = ""
    @State private var devNickname = "iOS Dev"
#endif

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
#if DEBUG
            devLoginSection
#endif
        }
        .frame(maxWidth: .infinity)
    }

    private var socialButtons: some View {
        HStack(spacing: 16) {
            AppleLoginButton {
                await appViewModel.signInWithApple()
            }
            .frame(width: 56, height: 56)

            KakaoLoginImageButton {
                await appViewModel.signInWithKakao()
            }
            .frame(width: 56, height: 56)

            GoogleLoginButton {
                await appViewModel.signInWithGoogle()
            }
            .frame(width: 56, height: 56)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("social_sign_in_row")
    }

    private var socialSectionHeader: some View {
        Text("Sign in with:")
            .appTypography(size: 16, weight: .semibold)
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.86) : LoginDesignTokens.textMuted)
            .accessibilityIdentifier("social_sign_in_header")
    }

#if DEBUG
    private var devLoginSection: some View {
        VStack(spacing: 10) {
            TextField("dev account", text: $devAccountKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .devLoginFieldStyle(colorScheme: colorScheme)
                .accessibilityIdentifier("dev_login_account_field")

            SecureField("dev code", text: $devSecret)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .devLoginFieldStyle(colorScheme: colorScheme)
                .accessibilityIdentifier("dev_login_secret_field")

            TextField("nickname", text: $devNickname)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .devLoginFieldStyle(colorScheme: colorScheme)
                .accessibilityIdentifier("dev_login_nickname_field")

            Button {
                Task {
                    await appViewModel.signInWithDevAccount(
                        accountKey: devAccountKey,
                        devSecret: devSecret,
                        nickname: devNickname
                    )
                }
            } label: {
                Text("개발 계정 로그인")
                    .appTypography(size: 14, weight: .semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(LoginDesignTokens.brandPrimary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityIdentifier("dev_login_button")
        }
        .padding(.top, 8)
    }
#endif

    private func clamped(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

#if DEBUG
private extension View {
    func devLoginFieldStyle(colorScheme: ColorScheme) -> some View {
        self
            .textFieldStyle(.plain)
            .appTypography(size: 14, weight: .medium)
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : LoginDesignTokens.textMain)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(
                colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.74),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(LoginDesignTokens.borderLight.opacity(colorScheme == .dark ? 0.3 : 0.8), lineWidth: 1)
            }
    }
}
#endif

#if DEBUG
#Preview {
    LoginEntryView()
        .environmentObject(AppViewModel.preview(route: .login, currentUser: nil, session: nil))
}
#endif
