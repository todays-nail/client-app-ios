//
//  HomePromoBannerSectionView.swift
//  NailClient
//

import SwiftUI

struct HomePromoBannerSectionView: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: HomeDesignTokens.bannerCornerRadius, style: .continuous)
                    .fill(HomeDesignTokens.bannerBackground)

                Image(HomeMockData.promoImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 0.45, height: height)
                    .clipped()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                BannerDiagonalOverlayShape()
                    .fill(HomeDesignTokens.bannerOverlay)
                    .opacity(0.72)
                    .frame(width: width * 0.62, height: height)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 6) {
                    Text(HomeMockData.promoTitle)
                        .font(.system(size: 24, weight: .heavy))
                        .lineSpacing(2)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(HomeMockData.promoDescription)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    NavigationLink {
                        AINailGenerationView()
                    } label: {
                        Text("AI 네일 생성")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(HomeDesignTokens.accent)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .frame(width: width * 0.60, alignment: .leading)
                .padding(.leading, 20)
                .padding(.vertical, 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: HomeDesignTokens.bannerCornerRadius, style: .continuous))
        }
        .frame(height: 160)
    }
}

private struct BannerDiagonalOverlayShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.22, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}
