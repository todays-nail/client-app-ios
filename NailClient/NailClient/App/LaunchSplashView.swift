//
//  LaunchSplashView.swift
//  NailClient
//

import SwiftUI

struct LaunchSplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LoginBackgroundView()

            VStack(spacing: 18) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 96)

                Text("오늘 네일")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : LoginDesignTokens.textMain)

                ProgressView()
                    .tint(LoginDesignTokens.brandPrimary)
                    .padding(.top, 2)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LaunchSplashView()
}
