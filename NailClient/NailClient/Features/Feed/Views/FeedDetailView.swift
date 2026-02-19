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
    @State private var isReservationSheetPresented: Bool = false
    @State private var isReservationPickerSheetPresented: Bool = false
    @State private var reservationOptions: [FeedReservationOption] = FeedReservationOption.defaultTemplates
    @State private var selectedOptionQuantities: [String: Int] = FeedReservationOption.defaultQuantityMap
    @State private var selectedReservationDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var slotsByDateKey: [String: [ReservationSlotResponse]] = [:]
    @State private var selectedReservationSlotID: UUID?
    @State private var isAvailabilityLoading: Bool = false
    @State private var availabilityErrorMessage: String?
    @State private var closedWeekdays: Set<String> = []
    @State private var preparedShopID: UUID?
    @State private var isReservationSubmitting: Bool = false
    @State private var reservationGuideMessage: String?
    @State private var reservationErrorMessage: String?
    @State private var reservationSuccessMessage: String?
    @State private var selectedShopID: UUID?
    @State private var isResolvingShopNavigation: Bool = false
    @State private var shopNavigationErrorMessage: String?

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
                    } else if shouldShowDetailLoadFailure {
                        detailLoadFailureView(topInset: proxy.safeAreaInsets.top)
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
                } else if !shouldShowDetailLoadFailure {
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
            await prepareReservationAvailabilityIfNeeded(force: false)
        }
        .onChange(of: viewModel.detail?.shopId) { _, _ in
            Task {
                await prepareReservationAvailabilityIfNeeded(force: true)
            }
        }
        .onChange(of: selectedReservationDate) { _, _ in
            Task {
                await ensureSlotsLoadedAndSelectDefault(for: selectedReservationDate)
            }
        }
        .alert("좋아요 반영 실패", isPresented: likeErrorAlertBinding) {
            Button("확인", role: .cancel) {
                viewModel.likeErrorMessage = nil
            }
        } message: {
            Text(viewModel.likeErrorMessage ?? "좋아요 반영에 실패했어요.")
        }
        .alert("안내", isPresented: reservationGuideAlertBinding) {
            Button("확인", role: .cancel) {
                reservationGuideMessage = nil
            }
        } message: {
            Text(reservationGuideMessage ?? "")
        }
        .sheet(isPresented: $isReservationPickerSheetPresented) {
            reservationPickerSheetContent
        }
        .sheet(isPresented: $isReservationSheetPresented) {
            reservationSheetContent
        }
        .alert("예약 실패", isPresented: reservationErrorAlertBinding) {
            Button("확인", role: .cancel) {
                reservationErrorMessage = nil
            }
        } message: {
            Text(reservationErrorMessage ?? "예약 처리에 실패했어요.")
        }
        .alert("예약 완료", isPresented: reservationSuccessAlertBinding) {
            Button("확인", role: .cancel) {
                reservationSuccessMessage = nil
            }
        } message: {
            Text(reservationSuccessMessage ?? "예약이 완료되었어요.")
        }
        .alert("샵 상세 이동 실패", isPresented: shopNavigationErrorAlertBinding) {
            Button("확인", role: .cancel) {
                shopNavigationErrorMessage = nil
            }
        } message: {
            Text(shopNavigationErrorMessage ?? "샵 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
        .navigationDestination(isPresented: shopNavigationIsPresentedBinding) {
            if let selectedShopID {
                ShopDetailView(shopID: selectedShopID)
                    .environmentObject(appViewModel)
            } else {
                EmptyView()
            }
        }
    }

    private var shouldShowDetailLoadFailure: Bool {
        viewModel.detail == nil && (viewModel.errorMessage?.isEmpty == false)
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
                    fallbackHeroImage
                @unknown default:
                    fallbackHeroImage
                }
            }
        case .local:
            fallbackHeroImage
        }
    }

    private var fallbackHeroImage: some View {
        ZStack {
            FeedDesignTokens.detailPlaceholderBackground
            ProgressView()
                .tint(FeedDesignTokens.accent)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                detailInlineErrorBanner(message: errorMessage)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(studioName.uppercased())
                    .appTypography(size: 17, weight: .black)
                    .foregroundStyle(FeedDesignTokens.accent)

                Text(designTitle)
                    .appTypography(size: 25, weight: .heavy)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                    .lineSpacing(4)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .appTypography(size: 12, weight: .semibold)
                    Text(locationText)
                    Text("•")
                    Text(distanceText)
                    Spacer(minLength: 8)
                    Image(systemName: "heart.fill")
                        .foregroundStyle(viewModel.isLiked ? FeedDesignTokens.accent : FeedDesignTokens.detailLikeInactive)
                    Text("좋아요 \(viewModel.likeCount)")
                }
                .appTypography(size: 13, weight: .medium)
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }

            VStack(alignment: .leading, spacing: 14) {
                priceCard
                tagSection
                studioInfoSection
                reservationCardSection
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

    private func detailLoadFailureView(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                topCircleButton(systemName: "chevron.left") {
                    dismiss()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset + 14)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .appTypography(size: 22, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.accent)

                Text("상세 정보를 불러오지 못했어요")
                    .appTypography(size: 19, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Text(viewModel.errorMessage ?? "잠시 후 다시 시도해 주세요.")
                    .appTypography(size: 14, weight: .medium)
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("다시 시도") {
                    Task {
                        await retryDetailLoad()
                    }
                }
                .appTypography(size: 14, weight: .bold)
                .foregroundStyle(FeedDesignTokens.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(FeedDesignTokens.detailCardBackground)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                        )
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed.detail.retry")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FeedDesignTokens.detailCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }

    private func detailInlineErrorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .appTypography(size: 12, weight: .semibold)
                .foregroundStyle(FeedDesignTokens.accent)
                .padding(.top, 1)

            Text(message)
                .appTypography(size: 12, weight: .medium)
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FeedDesignTokens.detailSubCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                )
        )
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOTAL PRICE")
                .appTypography(size: 13, weight: .medium)
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(formattedPrice(discountedPrice))
                    .appTypography(size: 38, weight: .heavy)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Spacer(minLength: 8)

                Text("\(discountPercent)% OFF")
                    .appTypography(size: 16, weight: .heavy)
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
                .appTypography(size: 21, weight: .medium)
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
                        .appTypography(size: 13, weight: .semibold)
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
        Button {
            navigateToShopDetail()
        } label: {
            studioInfoRow(
                showChevron: !isResolvingShopNavigation,
                showProgress: isResolvingShopNavigation
            )
        }
        .buttonStyle(.plain)
        .disabled(isResolvingShopNavigation)
        .padding(.vertical, 4)
        .accessibilityLabel("샵 상세 보기")
        .accessibilityHint("선택한 샵 상세 화면으로 이동")
    }

    private func studioInfoRow(showChevron: Bool, showProgress: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(FeedDesignTokens.detailStudioFill)
                Image(systemName: "building.2.fill")
                    .appTypography(size: 18, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.detailStudioIcon)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(studioName)
                    .appTypography(size: 18, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                Text(String(format: "평점 %.1f · 리뷰 %,d", ratingAvg, reviewCount))
                    .appTypography(size: 13, weight: .medium)
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }

            Spacer()

            if showProgress {
                ProgressView()
                    .controlSize(.small)
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .appTypography(size: 14, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }
        }
        .fullRowTapTarget(alignment: .leading)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("디자인 설명")
                .appTypography(size: 26, weight: .heavy)
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)

            Text(designDescription)
                .appTypography(size: 16, weight: .medium)
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                .lineSpacing(4)

            Text("소요 시간: 약 \(durationMin)분 (제거 미포함)")
                .appTypography(size: 15, weight: .medium)
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("리뷰 (\(reviewCount))")
                    .appTypography(size: 28, weight: .heavy)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Spacer()

                Button("전체보기") {
                }
                .appTypography(size: 15, weight: .bold)
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
                    .appTypography(size: 13, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.detailTagText)
                Spacer()
                Text(String(repeating: "★", count: max(1, min(5, review.rating))))
                    .appTypography(size: 12, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.detailReviewStar)
            }

            Text(review.comment)
                .appTypography(size: 13, weight: .medium)
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
                if isDesignSelectionMode {
                    selectCurrentDesignForAI()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text(isDesignSelectionMode ? "이 디자인 선택하기" : "AI로 내 손에 적용해보기")
                }
                .appTypography(size: 17, weight: .heavy)
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
                presentReservationSheet()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                    Text("예약하기")
                }
                .appTypography(size: 16, weight: .bold)
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

    private var reservationPickerSheetContent: some View {
        FeedDetailReservationPickerSheetView(
            selectedDate: $selectedReservationDate,
            dateRange: reservationDateRange,
            slotsForSelectedDate: reservationSlotsForSelectedDate,
            selectedSlotID: selectedReservationSlotID,
            isLoading: isAvailabilityLoading,
            isClosed: isSelectedDateClosed,
            errorMessage: availabilityErrorMessage,
            onTapSlot: { slot in
                selectedReservationSlotID = slot.id
            },
            onRetry: {
                Task {
                    await loadSlots(from: selectedReservationDate, days: 1, force: true)
                    applyDefaultSlotSelection(for: selectedReservationDate)
                }
            },
            onDone: {
                isReservationPickerSheetPresented = false
            }
        )
        .presentationDetents([.medium, .large])
    }

    private var reservationSheetContent: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        reservationOptionSection
                        reservationCostSection
                        reservationSelectionSummarySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                Button {
                    Task {
                        await submitReservation()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isReservationSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("예약 확정")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            (selectedReservationSlotID == nil || isReservationSubmitting)
                                ? FeedDesignTokens.detailActionBorder
                                : FeedDesignTokens.accent
                        )
                )
                .disabled(selectedReservationSlotID == nil || isReservationSubmitting)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .navigationTitle("예약 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        isReservationSheetPresented = false
                    }
                }
            }
        }
    }

    private func topCircleButton(systemName: String, foreground: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .appTypography(size: 18, weight: .bold)
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

    private var reservationGuideAlertBinding: Binding<Bool> {
        Binding(
            get: { reservationGuideMessage?.isEmpty == false },
            set: { shouldShow in
                if !shouldShow {
                    reservationGuideMessage = nil
                }
            }
        )
    }

    private var reservationErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { reservationErrorMessage?.isEmpty == false },
            set: { shouldShow in
                if !shouldShow {
                    reservationErrorMessage = nil
                }
            }
        )
    }

    private var reservationSuccessAlertBinding: Binding<Bool> {
        Binding(
            get: { reservationSuccessMessage?.isEmpty == false },
            set: { shouldShow in
                if !shouldShow {
                    reservationSuccessMessage = nil
                }
            }
        )
    }

    private var shopNavigationErrorAlertBinding: Binding<Bool> {
        Binding(
            get: { shopNavigationErrorMessage?.isEmpty == false },
            set: { shouldShow in
                if !shouldShow {
                    shopNavigationErrorMessage = nil
                }
            }
        )
    }

    private var shopNavigationIsPresentedBinding: Binding<Bool> {
        Binding(
            get: { selectedShopID != nil },
            set: { isActive in
                if !isActive {
                    selectedShopID = nil
                }
            }
        )
    }

    private func navigateToShopDetail() {
        guard !isResolvingShopNavigation else { return }

        Task { @MainActor in
            isResolvingShopNavigation = true
            defer { isResolvingShopNavigation = false }

            if let shopID = await viewModel.resolveShopIdForNavigation() {
                selectedShopID = shopID
            } else {
                shopNavigationErrorMessage = "샵 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    private var isDesignSelectionMode: Bool {
        appViewModel.isAIDesignSelectionInProgress
    }

    private var currentGallerySource: GallerySource {
        let sources = gallerySources
        guard !sources.isEmpty else {
            return .local(viewModel.item.fallbackAssetName)
        }
        let clampedIndex = min(max(selectedImageIndex, 0), sources.count - 1)
        return sources[clampedIndex]
    }

    private func presentReservationSheet() {
        guard selectedReservationSlotID != nil else {
            reservationGuideMessage = "날짜와 시간을 먼저 선택해 주세요."
            return
        }
        reservationOptions = FeedReservationOption.defaultTemplates
        selectedOptionQuantities = FeedReservationOption.defaultQuantityMap
        isReservationSheetPresented = true
    }

    private func selectCurrentDesignForAI() {
        let source: AIDesignSelectionPayload.Source
        switch currentGallerySource {
        case .remote(let url):
            source = .remoteURL(url.absoluteString)
        case .local(let name):
            source = .localAsset(name)
        }

        appViewModel.completeAIDesignSelection(with: source)
        dismiss()
    }

    private func retryDetailLoad() async {
        await viewModel.reload()
        await prepareReservationAvailabilityIfNeeded(force: true)
    }

    private func prepareReservationAvailabilityIfNeeded(force: Bool) async {
        let shopID = viewModel.detail?.shopId
        if !force, preparedShopID == shopID, !slotsByDateKey.isEmpty {
            return
        }

        preparedShopID = shopID
        availabilityErrorMessage = nil
        slotsByDateKey = [:]
        selectedReservationSlotID = nil
        selectedReservationDate = Calendar.current.startOfDay(for: Date())

        if let shopID {
            await loadBusinessHoursIfNeeded(shopId: shopID)
        } else {
            closedWeekdays = []
        }

        await loadSlots(from: selectedReservationDate, days: 7, force: true)
        if let earliestSlot = FeedReservationAvailability.earliestSlot(in: slotsByDateKey) {
            selectedReservationDate = Calendar.current.startOfDay(for: earliestSlot.startAt)
            selectedReservationSlotID = earliestSlot.id
        }
    }

    private func loadBusinessHoursIfNeeded(shopId: UUID) async {
        do {
            let response = try await appViewModel.fetchShopDetail(shopId: shopId)
            closedWeekdays = FeedReservationAvailability.makeClosedWeekdaySet(response.shop.closedWeekdays ?? [])
        } catch {
            closedWeekdays = []
        }
    }

    private func loadSlots(from date: Date, days: Int, force: Bool) async {
        let key = FeedReservationAvailability.dateKey(for: date)
        if !force, days == 1, slotsByDateKey[key] != nil {
            return
        }
        if isAvailabilityLoading { return }

        isAvailabilityLoading = true
        defer { isAvailabilityLoading = false }

        do {
            let response = try await appViewModel.fetchReservationSlots(
                referenceId: viewModel.item.id,
                fromDate: key,
                days: days
            )

            let groupedByDateKey = FeedReservationAvailability.groupedSlotsByDateKey(response.slots)
            if days > 1 {
                let dateKeys = FeedReservationAvailability.dateKeys(startingAt: date, days: days)
                for dateKey in dateKeys {
                    slotsByDateKey[dateKey] = groupedByDateKey[dateKey] ?? []
                }
            } else {
                slotsByDateKey[key] = groupedByDateKey[key] ?? []
            }

            if let selectedReservationSlotID,
               slotsByDateKey.values.flatMap({ $0 }).contains(where: { $0.id == selectedReservationSlotID }) == false {
                self.selectedReservationSlotID = nil
            }
            availabilityErrorMessage = nil
        } catch {
            let rawMessage = error.localizedDescription.lowercased()
            if rawMessage.contains("shop booking is disabled") {
                availabilityErrorMessage = "현재 예약을 준비 중인 샵입니다."
            } else if rawMessage.contains("reference is inactive") {
                availabilityErrorMessage = "현재 예약을 지원하지 않는 디자인입니다."
            } else {
                availabilityErrorMessage = "예약 가능 시간을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    private func ensureSlotsLoadedAndSelectDefault(for date: Date) async {
        let key = FeedReservationAvailability.dateKey(for: date)
        if slotsByDateKey[key] == nil {
            await loadSlots(from: date, days: 1, force: false)
        }
        applyDefaultSlotSelection(for: date)
    }

    private func applyDefaultSlotSelection(for date: Date) {
        selectedReservationSlotID = FeedReservationAvailability.firstSlot(for: date, in: slotsByDateKey)?.id
    }

    private func submitReservation() async {
        guard let selectedReservationSlotID else { return }
        if isReservationSubmitting { return }

        isReservationSubmitting = true
        defer { isReservationSubmitting = false }

        do {
            _ = try await appViewModel.createReservation(
                referenceId: viewModel.item.id,
                slotId: selectedReservationSlotID,
                selectedOptionsSnapshot: selectedOptionsPayload,
                attachedImageURL: nil,
                aiGenerationId: nil
            )

            await loadSlots(from: selectedReservationDate, days: 1, force: true)
            applyDefaultSlotSelection(for: selectedReservationDate)
            isReservationSheetPresented = false
            appViewModel.syncSelectedMainTab(.reservations)
            reservationSuccessMessage = "예약이 완료되었어요."
            NotificationCenter.default.post(name: .reservationCreated, object: nil)
        } catch {
            reservationErrorMessage = "예약 처리에 실패했어요. 이미 선점된 슬롯일 수 있어요."
        }
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
            "#감성네일",
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

    private var optionAdditionalPrice: Int {
        reservationOptions.reduce(0) { partialResult, option in
            partialResult + (normalizedQuantity(for: option) * option.unitPrice)
        }
    }

    private var reservationEstimatedTotalPrice: Int {
        discountedPrice + optionAdditionalPrice
    }

    private var selectedOptionsPayload: [String: Int]? {
        let payload = reservationOptions.reduce(into: [String: Int]()) { partialResult, option in
            let quantity = normalizedQuantity(for: option)
            if quantity > 0 {
                partialResult[option.id] = quantity
            }
        }
        return payload.isEmpty ? nil : payload
    }

    private var reservationOptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("예약 옵션")
                .appTypography(size: 17, weight: .bold)
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)

            ForEach(reservationOptions) { option in
                FeedReservationOptionRowView(
                    option: option,
                    quantity: optionQuantityBinding(for: option),
                    unitPriceText: formattedPrice(option.unitPrice)
                )
            }
        }
        .accessibilityIdentifier("reservation.sheet.option.section")
    }

    private var reservationCostSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("예상 비용")
                .appTypography(size: 17, weight: .bold)
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)

            VStack(spacing: 8) {
                costRow(title: "기본 시술가", value: formattedPrice(discountedPrice))
                costRow(title: "옵션 추가금", value: "+\(formattedPrice(optionAdditionalPrice))")
                Divider()
                    .overlay(FeedDesignTokens.detailBorder)
                costRow(title: "총 예상 금액", value: formattedPrice(reservationEstimatedTotalPrice), isEmphasis: true)
                    .accessibilityIdentifier("reservation.sheet.cost.total")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FeedDesignTokens.detailSubCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var reservationCardSection: some View {
        FeedDetailReservationCardView(
            selectedDate: selectedReservationDate,
            selectedSlot: selectedReservationSlot,
            slotsForSelectedDate: reservationSlotsForSelectedDate,
            isLoading: isAvailabilityLoading,
            isClosed: isSelectedDateClosed,
            errorMessage: availabilityErrorMessage,
            onTapDateTimeRow: {
                isReservationPickerSheetPresented = true
            },
            onTapSlot: { slot in
                selectedReservationSlotID = slot.id
            },
            onRetry: {
                Task {
                    await loadSlots(from: selectedReservationDate, days: 1, force: true)
                    applyDefaultSlotSelection(for: selectedReservationDate)
                }
            }
        )
        .accessibilityIdentifier("reservation.detail.slot.section")
    }

    private var reservationSelectionSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("선택 일정")
                .appTypography(size: 17, weight: .bold)
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedReservationSummaryText)
                    .appTypography(size: 15, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Text("상세 화면에서 날짜/시간을 변경할 수 있어요.")
                    .appTypography(size: 12, weight: .medium)
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FeedDesignTokens.detailSubCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var reservationDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return start...end
    }

    private var reservationSlotsForSelectedDate: [ReservationSlotResponse] {
        FeedReservationAvailability.slots(for: selectedReservationDate, in: slotsByDateKey)
    }

    private var isSelectedDateClosed: Bool {
        FeedReservationAvailability.isClosed(
            date: selectedReservationDate,
            closedWeekdays: closedWeekdays
        )
    }

    private var selectedReservationSummaryText: String {
        guard let selectedReservationSlot else {
            return "선택된 예약 일정이 없어요."
        }
        return Self.reservationSlotFormatter.string(from: selectedReservationSlot.startAt)
    }

    private var selectedReservationSlot: ReservationSlotResponse? {
        guard let selectedReservationSlotID else { return nil }
        return slotsByDateKey.values
            .flatMap { $0 }
            .first(where: { $0.id == selectedReservationSlotID })
    }

    private func optionQuantityBinding(for option: FeedReservationOption) -> Binding<Int> {
        Binding(
            get: { normalizedQuantity(for: option) },
            set: { newValue in
                selectedOptionQuantities[option.id] = min(max(newValue, 0), option.maxQuantity)
            }
        )
    }

    private func normalizedQuantity(for option: FeedReservationOption) -> Int {
        min(max(selectedOptionQuantities[option.id] ?? option.defaultQuantity, 0), option.maxQuantity)
    }

    private func costRow(title: String, value: String, isEmphasis: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .appTypography(size: isEmphasis ? 15 : 14, weight: isEmphasis ? .bold : .medium)
                .foregroundStyle(isEmphasis ? FeedDesignTokens.detailPrimaryText : FeedDesignTokens.detailSecondaryText)
            Spacer(minLength: 8)
            Text(value)
                .appTypography(size: isEmphasis ? 16 : 14, weight: isEmphasis ? .heavy : .semibold)
                .foregroundStyle(isEmphasis ? FeedDesignTokens.accent : FeedDesignTokens.detailPrimaryText)
        }
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

    private static let reservationSlotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E) HH:mm"
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
    .environmentObject(AppViewModel())
}
