//
//  FeedPromoBannerSectionView.swift
//  NailClient
//

import SwiftUI

struct FeedPromoBannerSectionView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = max(min(proxy.size.height, 176), 146)
            let imageWidth = width * 0.44
            let textInset = min(max(width * 0.054, 16), 22)
            let textMaxWidth = max(width - imageWidth - (textInset * 2) - 4, 132)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: FeedDesignTokens.bannerCornerRadius, style: .continuous)
                    .fill(FeedDesignTokens.bannerBackground)

                Image(FeedMockData.promoImageName)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(4.0 / 5.0, contentMode: .fill)
                    .frame(width: imageWidth, height: height)
                    .clipped()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .overlay(alignment: .trailing) {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                BannerDiagonalOverlayShape()
                    .fill(FeedDesignTokens.bannerOverlay)
                    .opacity(colorScheme == .dark ? 0.58 : 0.64)
                    .frame(width: width * 0.56, height: height)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 6) {
                    Text(FeedMockData.promoTitle)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .lineSpacing(2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(FeedMockData.promoDescription)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    NavigationLink {
                        AINailGenerationView()
                    } label: {
                        Text("AI 네일 생성")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(FeedDesignTokens.accent)
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
                .frame(maxWidth: textMaxWidth, alignment: .leading)
                .padding(.leading, textInset)
                .padding(.trailing, imageWidth + 6)
                .padding(.vertical, 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: FeedDesignTokens.bannerCornerRadius, style: .continuous))
        }
        .frame(height: 160)
    }
}

private struct BannerDiagonalOverlayShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.34, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}
