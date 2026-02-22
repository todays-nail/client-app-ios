//
//  KakaoLoginImageButton.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct KakaoLoginImageButton: View {
    let action: () async -> Void

    var body: some View {
        SocialSquareLoginButton(
            assetName: "social_kakao_square",
            accessibilityLabel: "카카오로 로그인",
            accessibilityIdentifier: "kakao_sign_in_button",
            action: action
        )
    }
}

#Preview {
    KakaoLoginImageButton {}
        .padding()
}
