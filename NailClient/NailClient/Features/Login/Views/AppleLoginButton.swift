//
//  AppleLoginButton.swift
//  NailClient
//

import AuthenticationServices
import SwiftUI

struct AppleLoginButton: View {
    let action: @Sendable () async -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading = false

    private var buttonStyle: ASAuthorizationAppleIDButton.Style {
        colorScheme == .dark ? .white : .black
    }

    private var buttonStyleIdentifier: String {
        colorScheme == .dark ? "apple-sign-in-white" : "apple-sign-in-black"
    }

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
                AppleIDButtonRepresentable(style: buttonStyle)
                    .id(buttonStyleIdentifier)
                    .frame(height: 56)

                if isLoading {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(0.12))
                        .overlay {
                            ProgressView()
                                .tint(colorScheme == .dark ? .black : .white)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityIdentifier("apple_sign_in_button")
    }
}

private struct AppleIDButtonRepresentable: UIViewRepresentable {
    let style: ASAuthorizationAppleIDButton.Style

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: style
        )
        button.cornerRadius = 12
        button.isUserInteractionEnabled = false
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        _ = uiView
        _ = context
    }
}

#Preview {
    AppleLoginButton {}
        .padding()
}
