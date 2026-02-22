//
//  AppleLoginButton.swift
//  NailClient
//

import SwiftUI

struct AppleLoginButton: View {
    let action: () async -> Void

    var body: some View {
        // NOTE:
        // ASAuthorizationAppleIDButton이 iOS 네이티브 권장 구현이지만,
        // 현재 제품 정책에 따라 아이콘형 네모 버튼으로 고정한다.
        SocialSquareLoginButton(
            assetName: "social_apple_square",
            accessibilityLabel: "Apple로 로그인",
            accessibilityIdentifier: "apple_sign_in_button",
            action: action
        )
    }
}

#Preview {
    AppleLoginButton {}
        .padding()
}
