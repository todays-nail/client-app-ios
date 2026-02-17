//
//  FeedDetailContentSectionView.swift
//  NailClient
//

import SwiftUI

struct FeedDetailContentSectionView: View {
    let isLiked: Bool
    let likeCount: Int
    let discountedPriceText: String
    let originalPriceText: String
    let discountPercent: Int
    let tags: [String]
    let reviewItems: [FeedDetailReview]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            VStack(alignment: .leading, spacing: 14) {
                priceCard
                tagSection
                studioInfoSection
            }
            Divider()
                .overlay(FeedDesignTokens.detailDivider)
            descriptionSection
            reviewSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 26)
        .background(FeedDesignTokens.detailCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .offset(y: -26)
        .padding(.bottom, -26)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GLOW NAIL STUDIO")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(FeedDesignTokens.accent)

            Text("시럽 그라데이션 & 미니멀 포인트 네일")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                .lineSpacing(4)

            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .semibold))
                Text("강남구 신사동")
                Text("•")
                Text("2.4km")
                Spacer(minLength: 8)
                Image(systemName: "heart.fill")
                    .foregroundStyle(isLiked ? FeedDesignTokens.accent : FeedDesignTokens.detailLikeInactive)
                Text("좋아요 \(likeCount)")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(FeedDesignTokens.detailSecondaryText)
        }
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOTAL PRICE")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(discountedPriceText)
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Spacer(minLength: 8)

                Text("\(discountPercent)% OFF")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(FeedDesignTokens.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(FeedDesignTokens.accent.opacity(0.14))
                    )
                    .offset(y: -4)
            }

            Text(originalPriceText)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailTertiaryText)
                .strikethrough()
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
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FeedDesignTokens.detailTagText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(FeedDesignTokens.detailTagBackground)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    private var studioInfoSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(FeedDesignTokens.detailStudioFill)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.detailStudioIcon)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Glow Nail Studio")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                Text("평점 4.9 · 리뷰 1,240")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FeedDesignTokens.detailTertiaryText)
        }
        .padding(.vertical, 4)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("디자인 설명")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)

            Text("투명한 시럽 베이스에 은은한 펄 포인트를 더한 디자인입니다. 어떤 피부 톤에도 자연스럽게 어울리고, 데일리부터 약속 있는 날까지 깔끔하게 연출할 수 있어요.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                .lineSpacing(4)

            Text("소요 시간: 약 60분 (제거 미포함)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("리뷰 (1,240)")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Spacer()

                Button("전체보기") {
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(FeedDesignTokens.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(reviewItems) { review in
                        reviewCard(review)
                    }
                }
            }
        }
    }

    private func reviewCard(_ review: FeedDetailReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(review.userName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.detailTagText)
                Spacer()
                Text(String(repeating: "★", count: review.rating))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FeedDesignTokens.detailReviewStar)
            }

            Text(review.comment)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
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

struct FeedDetailReview: Identifiable {
    let id = UUID()
    let userName: String
    let rating: Int
    let comment: String
}
