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
                let topSpacing = max(20, proxy.safeAreaInsets.top + (proxy.size.height * 0.04))
                let brandToActionSpacing = max(28, proxy.size.height * 0.10)
                let bottomSpacing = max(24, proxy.safeAreaInsets.bottom + (proxy.size.height * 0.14))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: topSpacing)

                        VStack(spacing: 0) {
                            branding
                                .padding(.top, 14)
                            Spacer(minLength: brandToActionSpacing)
                            actions
                        }
                        .frame(maxWidth: LoginDesignTokens.maxContentWidth)
                        .frame(maxWidth: .infinity)

                        Spacer(minLength: bottomSpacing)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                    .padding(24)
                }
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
        VStack(spacing: 12) {
            KakaoLoginImageButton(assetName: "kakao_login_large_wide") {
                await appViewModel.signInWithKakao()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: LoginDesignTokens.kakaoYellow.opacity(0.2), radius: 12, x: 0, y: 4)

            GoogleLoginButton {
                await appViewModel.signInWithGoogle()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    LoginEntryView()
        .environmentObject(AppViewModel())
}
