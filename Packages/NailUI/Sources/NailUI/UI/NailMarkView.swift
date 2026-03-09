//
//  NailMarkView.swift
//  NailClient
//
//  Created by Codex.
//

import SwiftUI

public struct NailMarkView: View {
    public init() {}

    public var body: some View {
        NailTipShape()
            .fill(
                LinearGradient(
                    colors: [LoginDesignTokens.peachGlow, LoginDesignTokens.coralGlow],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let h = proxy.size.height

                    ZStack(alignment: .topLeading) {
                        // Top highlight (HTML ::after)
                        Ellipse()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: w * 0.18, height: h * 0.35)
                            .blur(radius: 2)
                            .offset(x: w * 0.22, y: h * 0.12)

                        // Bottom glow (HTML ::before)
                        VStack {
                            Spacer(minLength: 0)
                            Ellipse()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: w * 0.75, height: h * 0.22)
                                .blur(radius: 1.5)
                                // HTML: bottom: -6px (slightly below bottom, clipped)
                                .offset(y: 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .clipShape(NailTipShape())
            .frame(width: 44, height: 66)
            .accessibilityHidden(true)
    }
}

private struct NailTipShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // A simple "nail tip" silhouette using curves (approximation of CSS border-radius combo).
        return Path { p in
            p.move(to: CGPoint(x: w * 0.20, y: h))
            p.addQuadCurve(
                to: CGPoint(x: 0, y: h * 0.72),
                control: CGPoint(x: 0, y: h)
            )
            p.addQuadCurve(
                to: CGPoint(x: w * 0.12, y: h * 0.12),
                control: CGPoint(x: 0, y: h * 0.35)
            )
            p.addQuadCurve(
                to: CGPoint(x: w * 0.50, y: 0),
                control: CGPoint(x: w * 0.25, y: 0)
            )
            p.addQuadCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.12),
                control: CGPoint(x: w * 0.75, y: 0)
            )
            p.addQuadCurve(
                to: CGPoint(x: w, y: h * 0.72),
                control: CGPoint(x: w, y: h * 0.35)
            )
            p.addQuadCurve(
                to: CGPoint(x: w * 0.80, y: h),
                control: CGPoint(x: w, y: h)
            )
            p.closeSubpath()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        NailMarkView()
        NailMarkView()
            .scaleEffect(2)
    }
    .padding()
    .background(
        LinearGradient(
            colors: [
                LoginDesignTokens.bgBase,
                LoginDesignTokens.peachGlow.opacity(0.24),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
