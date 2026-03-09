//
//  LoginBackgroundView.swift
//  NailClient
//
//  Created by Codex.
//

import SwiftUI
import NailUI

struct LoginBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let endRadius = max(size.width, size.height) * 0.9

            ZStack {
                if colorScheme == .dark {
                    LoginDesignTokens.backgroundDarkHTML

                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.07), location: 0.0),
                            .init(color: LoginDesignTokens.peachGlow.opacity(0.10), location: 0.35),
                            .init(color: LoginDesignTokens.coralGlow.opacity(0.18), location: 0.68),
                            .init(color: LoginDesignTokens.backgroundDarkHTML, location: 1.0),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: endRadius
                    )
                } else {
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
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    LoginBackgroundView()
}
