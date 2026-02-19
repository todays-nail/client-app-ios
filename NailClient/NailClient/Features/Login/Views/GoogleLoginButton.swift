//
//  GoogleLoginButton.swift
//  NailClient
//

import GoogleSignInSwift
import SwiftUI

struct GoogleLoginButton: View {
    let action: @Sendable () async -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false

    var body: some View {
        GoogleSignInButton(
            scheme: colorScheme == .dark ? .dark : .light,
            style: .wide,
            state: isLoading ? .disabled : .normal
        ) {
            guard !isLoading else { return }
            isLoading = true
            Task {
                await action()
                isLoading = false
            }
        }
        .accessibilityIdentifier("google_sign_in_button")
    }
}

#Preview {
    GoogleLoginButton {}
        .frame(height: 58)
        .padding()
}
