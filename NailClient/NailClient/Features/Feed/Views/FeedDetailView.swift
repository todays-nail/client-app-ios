//
//  FeedDetailView.swift
//  NailClient
//

import SwiftUI

struct FeedDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    let onLikeStateChange: (FeedItem.ID, Bool, Int) -> Void

    @StateObject private var viewModel: FeedDetailViewModel
    @State private var selectedImageIndex: Int = 0

    init(item: FeedItem, onLikeStateChange: @escaping (FeedItem.ID, Bool, Int) -> Void = { _, _, _ in }) {
        self.onLikeStateChange = onLikeStateChange
        _viewModel = StateObject(wrappedValue: FeedDetailViewModel(item: item))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.isInitialLoading {
                        FeedDetailSkeletonView(
                            topInset: proxy.safeAreaInsets.top,
                            onBack: { dismiss() }
                        )
                        .transition(.opacity)
                    } else {
                        heroSection(topInset: proxy.safeAreaInsets.top)
                        contentSection
                            .transition(.opacity)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(FeedDesignTokens.detailBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if viewModel.isInitialLoading {
                    skeletonBottomActionBar
                } else {
                    bottomActionBar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                if viewModel.isLoading && !viewModel.isInitialLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, proxy.safeAreaInsets.top + 22)
                        .padding(.trailing, 16)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: viewModel.isInitialLoading)
        }
        .enableInteractivePopGesture()
        .task {
            viewModel.bind(service: appViewModel)
            await viewModel.loadIfNeeded()
        }
        .alert("좋아요 반영 실패", isPresented: likeErrorAlertBinding) {
            Button("확인", role: .cancel) {
                viewModel.likeErrorMessage = nil
            }
        } message: {
            Text(viewModel.likeErrorMessage ?? "좋아요 반영에 실패했어요.")
        }
    }

    private func heroSection(topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedImageIndex) {
                ForEach(Array(gallerySources.enumerated()), id: \.offset) { index, source in
                    galleryImage(source)
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

                topCircleButton(systemName: viewModel.isLiked ? "heart.fill" : "heart", foreground: viewModel.isLiked ? .red : .white) {
                    toggleLike()
                }
                .disabled(viewModel.isLikeUpdating)
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset + 14)
        }
    }

    @ViewBuilder
    private func galleryImage(_ source: GallerySource) -> some View {
        switch source {
        case let .remote(url):
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                case .failure:
                    fallbackHeroImage
                case .empty:
                    ZStack {
                        FeedDesignTokens.detailPlaceholderBackground
                        ProgressView()
                            .tint(FeedDesignTokens.accent)
                    }
                @unknown default:
                    fallbackHeroImage
                }
            }
        case let .local(name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }

    private var fallbackHeroImage: some View {
        Image(viewModel.item.fallbackAssetName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(gallerySources.indices, id: \.self) { index in
                Circle()
                    .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(studioName.uppercased())
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(FeedDesignTokens.accent)

                Text(designTitle)
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                    .lineSpacing(4)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .semibold))
                    Text(locationText)
                    Text("•")
                    Text(distanceText)
                    Spacer(minLength: 8)
                    Image(systemName: "heart.fill")
                        .foregroundStyle(viewModel.isLiked ? FeedDesignTokens.accent : FeedDesignTokens.detailLikeInactive)
                    Text("좋아요 \(viewModel.likeCount)")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }

            VStack(alignment: .leading, spacing: 14) {
                priceCard
                tagSection
                studioInfoSection
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                HStack {
                    Text("상세 정보를 불러오지 못했어요")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Button("재시도") {
                        Task {
                            await viewModel.reload()
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHint(errorMessage)
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
            Text("TOTAL PRICE")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(formattedPrice(discountedPrice))
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Spacer(minLength: 8)

                Text("\(discountPercent)% OFF")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(FeedDesignTokens.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(FeedDesignTokens.accent.opacity(0.14))
                    )
                    .offset(y: -6)
            }

            Text(formattedPrice(originalPrice))
                .font(.system(size: 21, weight: .medium))
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
                        .font(.system(size: 13, weight: .semibold))
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
                Text(studioName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                Text(String(format: "평점 %.1f · 리뷰 %,d", ratingAvg, reviewCount))
                    .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)

            Text(designDescription)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                .lineSpacing(4)

            Text("소요 시간: 약 \(durationMin)분 (제거 미포함)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("리뷰 (\(reviewCount))")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Spacer()

                Button("전체보기") {
                }
                .font(.system(size: 15, weight: .bold))
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

    private func reviewCard(_ review: FeedReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(review.userName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.detailTagText)
                Spacer()
                Text(String(repeating: "★", count: max(1, min(5, review.rating))))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FeedDesignTokens.detailReviewStar)
            }

            Text(review.comment)
                .font(.system(size: 13, weight: .medium))
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

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("AI로 내 손에 적용해보기")
                }
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(FeedDesignTokens.accent)
                )
            }
            .buttonStyle(.plain)

            Button {
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                    Text("예약하기")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FeedDesignTokens.detailActionText)
                .frame(width: 126, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(FeedDesignTokens.detailCardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(FeedDesignTokens.detailCardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FeedDesignTokens.detailActionBorder)
                .frame(height: 1)
        }
    }

    private var skeletonBottomActionBar: some View {
        HStack(spacing: 12) {
            SkeletonBlock(height: 56, cornerRadius: 14)
            SkeletonBlock(width: 126, height: 56, cornerRadius: 14)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(FeedDesignTokens.detailCardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FeedDesignTokens.detailActionBorder)
                .frame(height: 1)
        }
        .accessibilityLabel("상세 정보를 불러오는 중")
    }

    private func topCircleButton(systemName: String, foreground: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(foreground)
                .frame(height: 56)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.32))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func toggleLike() {
        Task {
            guard let response = await viewModel.toggleLike() else { return }
            onLikeStateChange(response.postId, response.isLiked, response.likeCount)
        }
    }

    private var likeErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { (viewModel.likeErrorMessage?.isEmpty == false) },
            set: { shouldShow in
                if !shouldShow {
                    viewModel.likeErrorMessage = nil
                }
            }
        )
    }

    private var gallerySources: [GallerySource] {
        if let detail = viewModel.detail, !detail.galleryImageURLs.isEmpty {
            return detail.galleryImageURLs.map { .remote($0) }
        }

        let imageNames = FeedMockData.feedItems.map(\.imageName)
        guard let currentIndex = imageNames.firstIndex(of: viewModel.item.imageName), !imageNames.isEmpty else {
            return [.local(viewModel.item.imageName)]
        }

        return (0..<3).map { offset in
            .local(imageNames[(currentIndex + offset) % imageNames.count])
        }
    }

    private var discountedPrice: Int {
        if let value = viewModel.detail?.discountedPrice {
            return value
        }

        let base = 55_000
        let step = (viewModel.likeCount % 5) * 2_500
        return base + step
    }

    private var originalPrice: Int {
        viewModel.detail?.originalPrice ?? (discountedPrice + 13_000)
    }

    private var discountPercent: Int {
        let numerator = (originalPrice - discountedPrice) * 100
        return max(5, numerator / max(originalPrice, 1))
    }

    private var tags: [String] {
        if let styleTags = viewModel.detail?.styleTags, !styleTags.isEmpty {
            return styleTags.map { "#\($0.replacingOccurrences(of: " ", with: ""))" }
        }

        let rotated = rotate(allTagCandidates, by: stableTagOffset)
        return Array(rotated.prefix(3))
    }

    private var allTagCandidates: [String] {
        [
            "#\(viewModel.item.shapeCategory)네일",
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
        let seed = viewModel.item.imageName.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return seed % max(allTagCandidates.count, 1)
    }

    private func rotate(_ array: [String], by offset: Int) -> [String] {
        guard !array.isEmpty else { return [] }
        let normalized = ((offset % array.count) + array.count) % array.count
        if normalized == 0 { return array }
        return Array(array[normalized...]) + Array(array[..<normalized])
    }

    private var reviewItems: [FeedReview] {
        if let reviews = viewModel.detail?.recentReviews, !reviews.isEmpty {
            return reviews
        }

        return [
            FeedReview(
                userName: "user_0921",
                rating: 5,
                comment: "사진보다 실제가 더 예뻐요. 손이 길어 보이고 컬러가 차분해서 데일리로 딱입니다.",
                createdAt: Date()
            ),
            FeedReview(
                userName: "nail_lover",
                rating: 5,
                comment: "시럽 레이어가 맑게 올라가서 깔끔해요. 어떤 옷이랑도 잘 어울립니다.",
                createdAt: Date().addingTimeInterval(-60)
            ),
            FeedReview(
                userName: "daily_beauty",
                rating: 4,
                comment: "전체적으로 만족! 큐티클 라인 정리가 섬세해서 완성도가 높았어요.",
                createdAt: Date().addingTimeInterval(-120)
            )
        ]
    }

    private var studioName: String {
        viewModel.detail?.studioName ?? "GLOW NAIL STUDIO"
    }

    private var designTitle: String {
        viewModel.detail?.title ?? "시럽 그라데이션 & 미니멀 포인트 네일"
    }

    private var locationText: String {
        viewModel.detail?.locationText ?? "강남구 신사동"
    }

    private var distanceText: String {
        guard let distance = viewModel.detail?.distanceKM else {
            return "2.4km"
        }
        return String(format: "%.1fkm", distance)
    }

    private var designDescription: String {
        viewModel.detail?.description
            ?? "투명한 시럽 베이스에 은은한 펄 포인트를 더한 디자인입니다. 어떤 피부 톤에도 자연스럽게 어울리고, 데일리부터 약속 있는 날까지 깔끔하게 연출할 수 있어요."
    }

    private var durationMin: Int {
        viewModel.detail?.durationMin ?? 60
    }

    private var reviewCount: Int {
        viewModel.detail?.reviewCount ?? reviewItems.count
    }

    private var ratingAvg: Double {
        viewModel.detail?.ratingAvg ?? 4.9
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

private enum GallerySource: Hashable {
    case remote(URL)
    case local(String)
}

#Preview {
    NavigationStack {
        FeedDetailView(item: FeedMockData.feedItems[0])
    }
}
