//
//  GoogleLoginButton.swift
//  NailClient
//

import SwiftUI

struct GoogleLoginButton: View {
    let action: () async -> Void

    var body: some View {
        SocialSquareLoginButton(
            assetName: "social_google_square",
            accessibilityLabel: "Google로 로그인",
            accessibilityIdentifier: "google_sign_in_button",
            action: action
        )
    }
}

#Preview {
    GoogleLoginButton {}
        .padding()
}
