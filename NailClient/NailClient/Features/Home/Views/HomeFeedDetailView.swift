//
//  HomeFeedDetailView.swift
//  NailClient
//

import SwiftUI

struct HomeFeedDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: HomeFeedItem
    let onToggleLike: () -> Void

    @State private var selectedImageIndex: Int = 0
    @State private var isLiked: Bool
    @State private var likeCount: Int

    init(item: HomeFeedItem, onToggleLike: @escaping () -> Void = {}) {
        self.item = item
        self.onToggleLike = onToggleLike
        _isLiked = State(initialValue: item.isLiked)
        _likeCount = State(initialValue: item.likeCount)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection(topInset: proxy.safeAreaInsets.top)
                    contentSection
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(hex: 0xF4F5F8).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func heroSection(topInset: CGFloat) -> some View {
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
                topCircleButton(systemName: "chevron.left") {
                    dismiss()
                }

                Spacer()

                topCircleButton(systemName: "square.and.arrow.up") {
                }

                topCircleButton(systemName: isLiked ? "heart.fill" : "heart", foreground: isLiked ? .red : .white) {
                    toggleLike()
                }
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

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("GLOW NAIL STUDIO")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(HomeDesignTokens.accent)

                Text("시럽 그라데이션 & 미니멀 포인트 네일")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x171A22))
                    .lineSpacing(4)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 13, weight: .semibold))
                    Text("강남구 신사동")
                    Text("•")
                    Text("2.4km")
                    Spacer(minLength: 8)
                    Image(systemName: "heart.fill")
                        .foregroundStyle(isLiked ? HomeDesignTokens.accent : Color(hex: 0x9CA6B8))
                    Text("좋아요 \(likeCount)")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0x687184))
            }

            VStack(alignment: .leading, spacing: 14) {
                priceCard
                tagSection
                studioInfoSection
            }

            Divider()
                .overlay(Color(hex: 0xECEFF4))

            descriptionSection

            reviewSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 26)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .offset(y: -26)
        .padding(.bottom, -26)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOTAL PRICE")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0x667085))

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(formattedPrice(discountedPrice))
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x161A22))

                Spacer(minLength: 8)

                Text("\(discountPercent)% OFF")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(HomeDesignTokens.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HomeDesignTokens.accent.opacity(0.14))
                    )
                    .offset(y: -4)
            }

            Text(formattedPrice(originalPrice))
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color(hex: 0x99A0AE))
                .strikethrough()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0xF7F8FB))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: 0xE6EAF2), lineWidth: 1)
                )
        )
    }

    private var tagSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x384153))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0xF5F6F9))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color(hex: 0xE6EAF1), lineWidth: 1)
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
                    .fill(Color(hex: 0xFFF3E8))
                Image(systemName: "building.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xCF7A3D))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Glow Nail Studio")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: 0x161A22))
                Text("평점 4.9 · 리뷰 1,240")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x687184))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: 0x8A94A7))
        }
        .padding(.vertical, 4)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("디자인 설명")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Color(hex: 0x171A22))

            Text("투명한 시럽 베이스에 은은한 펄 포인트를 더한 디자인입니다. 어떤 피부 톤에도 자연스럽게 어울리고, 데일리부터 약속 있는 날까지 깔끔하게 연출할 수 있어요.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: 0x3B4354))
                .lineSpacing(4)

            Text("소요 시간: 약 60분 (제거 미포함)")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(hex: 0x5D677A))
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("리뷰 (1,240)")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x171A22))

                Spacer()

                Button("전체보기") {
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(HomeDesignTokens.accent)
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

    private func reviewCard(_ review: HomeFeedDetailReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(review.userName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2F3748))
                Spacer()
                Text(String(repeating: "★", count: review.rating))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF6B81B))
            }

            Text(review.comment)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0x455063))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xF7F8FB))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: 0xE8EBF2), lineWidth: 1)
                )
        )
    }

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(HomeDesignTokens.accent)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(HomeDesignTokens.accent.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(HomeDesignTokens.accent.opacity(0.26), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Button {
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("AI로 내 손에 적용해보기")
                }
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(HomeDesignTokens.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: 0xEAEFF5))
                .frame(height: 1)
        }
    }

    private func topCircleButton(systemName: String, foreground: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.32))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func toggleLike() {
        if isLiked {
            likeCount = max(0, likeCount - 1)
        } else {
            likeCount += 1
        }
        isLiked.toggle()
        onToggleLike()
    }

    private var galleryImageNames: [String] {
        let imageNames = HomeMockData.feedItems.map(\.imageName)
        guard let currentIndex = imageNames.firstIndex(of: item.imageName), !imageNames.isEmpty else {
            return [item.imageName]
        }

        return (0..<3).map { offset in
            imageNames[(currentIndex + offset) % imageNames.count]
        }
    }

    private var discountedPrice: Int {
        let base = 55_000
        let step = (item.likeCount % 5) * 2_500
        return base + step
    }

    private var originalPrice: Int {
        discountedPrice + 13_000
    }

    private var discountPercent: Int {
        let numerator = (originalPrice - discountedPrice) * 100
        return max(5, numerator / max(originalPrice, 1))
    }

    private var tags: [String] {
        let rotated = rotate(allTagCandidates, by: stableTagOffset)
        return Array(rotated.prefix(3))
    }

    private var allTagCandidates: [String] {
        [
            "#\(item.shapeCategory)네일",
            "#시럽네일",
            "#그라데이션",
            "#데일리",
            "#심플",
            "#오피스룩",
            "#웨딩네일",
            "#봄네일",
            "#포인트아트",
            "#투명감",
            "#광택",
            "#젤네일"
        ]
    }

    private var stableTagOffset: Int {
        let seed = item.imageName.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return seed % allTagCandidates.count
    }

    private func rotate(_ array: [String], by offset: Int) -> [String] {
        guard !array.isEmpty else { return [] }
        let normalized = ((offset % array.count) + array.count) % array.count
        if normalized == 0 { return array }
        return Array(array[normalized...]) + Array(array[..<normalized])
    }

    private var reviewItems: [HomeFeedDetailReview] {
        [
            HomeFeedDetailReview(
                userName: "user_0921",
                rating: 5,
                comment: "사진보다 실제가 더 예뻐요. 손이 길어 보이고 컬러가 차분해서 데일리로 딱입니다."
            ),
            HomeFeedDetailReview(
                userName: "nail_lover",
                rating: 5,
                comment: "시럽 레이어가 맑게 올라가서 깔끔해요. 어떤 옷이랑도 잘 어울립니다."
            ),
            HomeFeedDetailReview(
                userName: "daily_beauty",
                rating: 4,
                comment: "전체적으로 만족! 큐티클 라인 정리가 섬세해서 완성도가 높았어요."
            )
        ]
    }

    private func formattedPrice(_ value: Int) -> String {
        Self.priceFormatter.string(from: NSNumber(value: value)) ?? "₩\(value)"
    }

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    NavigationStack {
        HomeFeedDetailView(item: HomeMockData.feedItems[0])
    }
}
