//
//  FeedDetailHeroSectionView.swift
//  NailClient
//

import SwiftUI

struct FeedDetailHeroSectionView: View {
    let galleryImageNames: [String]
    @Binding var selectedImageIndex: Int
    let topInset: CGFloat
    let isLiked: Bool
    let onBack: () -> Void
    let onShare: () -> Void
    let onToggleLike: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(galleryImageNames.enumerated()), id: \.offset) { index, imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .tag(index)
                }
            }
            .frame(height: 520 + topInset)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay(alignment: .bottom) {
                pageIndicator
                    .padding(.bottom, 20)
            }
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.34), .clear, Color.black.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            HStack(spacing: 12) {
                topCircleButton(systemName: "chevron.left", action: onBack)

                Spacer()

                topCircleButton(systemName: "square.and.arrow.up", action: onShare)

                topCircleButton(
                    systemName: isLiked ? "heart.fill" : "heart",
                    foreground: isLiked ? .red : .white,
                    action: onToggleLike
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset + 14)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(galleryImageNames.indices, id: \.self) { index in
                Circle()
                    .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func topCircleButton(systemName: String, foreground: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .appTypography(size: 18, weight: .bold)
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.32))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
