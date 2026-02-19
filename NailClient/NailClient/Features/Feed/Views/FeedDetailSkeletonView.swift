//
//  FeedDetailSkeletonView.swift
//  NailClient
//

import SwiftUI

struct FeedDetailSkeletonView: View {
    let topInset: CGFloat
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            heroSection
            contentSection
        }
        .background(FeedDesignTokens.skeletonBackground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("상세 정보를 불러오는 중")
    }

    private var heroSection: some View {
        ZStack(alignment: .top) {
            SkeletonBlock(height: 520 + topInset, cornerRadius: 0)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonBlock(width: 8, height: 8, shapeStyle: .circle)
                        }
                    }
                    .padding(.bottom, 20)
                }

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .appTypography(size: 18, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.32))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset + 14)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(width: 150, height: 16, cornerRadius: 8)
                SkeletonBlock(width: nil, height: 30, cornerRadius: 10)
                SkeletonBlock(width: 260, height: 30, cornerRadius: 10)

                HStack(spacing: 8) {
                    SkeletonBlock(width: 180, height: 13, cornerRadius: 7)
                    Spacer()
                    SkeletonBlock(width: 90, height: 13, cornerRadius: 7)
                }
                .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 14) {
                priceCard
                tagSection
                studioInfoSection
            }

            Divider()
                .overlay(FeedDesignTokens.detailDivider)

            VStack(alignment: .leading, spacing: 14) {
                SkeletonBlock(width: 140, height: 28, cornerRadius: 9)
                SkeletonBlock(height: 16, cornerRadius: 8)
                SkeletonBlock(width: nil, height: 16, cornerRadius: 8)
                SkeletonBlock(width: 220, height: 16, cornerRadius: 8)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SkeletonBlock(width: 120, height: 30, cornerRadius: 9)
                    Spacer()
                    SkeletonBlock(width: 52, height: 16, cornerRadius: 8)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    SkeletonBlock(width: 84, height: 13, cornerRadius: 7)
                                    Spacer()
                                    SkeletonBlock(width: 42, height: 12, cornerRadius: 6)
                                }
                                SkeletonBlock(width: nil, height: 14, cornerRadius: 7)
                                SkeletonBlock(width: 170, height: 14, cornerRadius: 7)
                            }
                            .padding(14)
                            .frame(width: 260, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(FeedDesignTokens.detailSubCardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 26)
        .background(FeedDesignTokens.detailCardBackground)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 30,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 30,
                style: .continuous
            )
        )
        .offset(y: -26)
        .padding(.bottom, -26)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonBlock(width: 96, height: 12, cornerRadius: 6)
            SkeletonBlock(width: 220, height: 44, cornerRadius: 11)
            SkeletonBlock(width: 110, height: 20, cornerRadius: 9)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FeedDesignTokens.detailSubCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                )
        )
    }

    private var tagSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonBlock(width: 78, height: 32, shapeStyle: .capsule)
                }
            }
        }
    }

    private var studioInfoSection: some View {
        HStack(spacing: 14) {
            SkeletonBlock(width: 52, height: 52, shapeStyle: .circle)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 150, height: 18, cornerRadius: 9)
                SkeletonBlock(width: 140, height: 13, cornerRadius: 7)
            }

            Spacer()

            SkeletonBlock(width: 14, height: 14, cornerRadius: 7)
        }
        .padding(.vertical, 4)
    }
}
