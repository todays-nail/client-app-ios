//
//  LoginBackgroundView.swift
//  NailClient
//
//  Created by Codex.
//

import SwiftUI

struct LoginBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let endRadius = max(size.width, size.height) * 0.9

            ZStack {
                LoginDesignTokens.bgBase

                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: LoginDesignTokens.peachGlow.opacity(0.15), location: 0.45),
                        .init(color: LoginDesignTokens.coralGlow.opacity(0.10), location: 0.85),
                        .init(color: LoginDesignTokens.bgBase, location: 1.0),
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: endRadius
                )
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    LoginBackgroundView()
}

