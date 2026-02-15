//
//  LoginEntryView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct LoginEntryView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = LoginEntryViewModel()

    var body: some View {
        ZStack {
            LoginBackgroundView()

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 48)

                        Spacer(minLength: 0)

                        VStack(spacing: 0) {
                            branding
                                .padding(.bottom, 64)

                            actions
                        }
                        .frame(maxWidth: LoginDesignTokens.maxContentWidth)
                        .frame(maxWidth: .infinity)

                        Spacer(minLength: 0)

                        LoginLegalFooterView(
                            onTapTerms: { viewModel.showComingSoon(.terms) },
                            onTapPrivacy: { viewModel.showComingSoon(.privacy) }
                        )
                        .frame(maxWidth: LoginDesignTokens.maxContentWidth)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(LoginDesignTokens.minScreenHeight, proxy.size.height))
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
            case .comingSoon(let kind):
                return Alert(
                    title: Text("준비중"),
                    message: Text("\(kind.rawValue)은(는) 준비중입니다."),
                    dismissButton: .cancel(Text("확인"))
                )
            }
        }
    }

    private var branding: some View {
        VStack(spacing: 0) {
            NailMarkView()
                .padding(.bottom, 48)

            VStack(spacing: 8) {
                Text("오늘 네일")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(LoginDesignTokens.textMain)
                    .tracking(-0.3)

                Text("TODAY'S NAIL")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(LoginDesignTokens.textMuted.opacity(0.7))
                    .tracking(2.8)
            }

            Text("고민말고, AI로 오늘 네일")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(LoginDesignTokens.textMuted.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .tracking(-0.2)
                .padding(.top, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            KakaoLoginImageButton(assetName: "kakao_login_large_wide") {
                await appViewModel.signInWithKakao()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: LoginDesignTokens.kakaoYellow.opacity(0.2), radius: 12, x: 0, y: 4)

            Button {
                viewModel.showComingSoon(.webLogin)
            } label: {
                Text("사장님이신가요? 웹으로 로그인하세요.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(LoginDesignTokens.textMuted.opacity(0.7))
                    .underline(true, color: LoginDesignTokens.borderLight)
                    .padding(.top, 32)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    LoginEntryView()
        .environmentObject(AppViewModel())
}
