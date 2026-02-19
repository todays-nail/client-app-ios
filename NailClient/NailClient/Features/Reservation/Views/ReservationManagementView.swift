//
//  ReservationManagementView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct ReservationManagementView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: ReservationViewModel
    private let initialSegment: ReservationSegment?

    init(initialSegment: ReservationSegment? = nil) {
        self.initialSegment = initialSegment
        _viewModel = StateObject(wrappedValue: ReservationViewModel())
    }

    init(
        viewModel: ReservationViewModel,
        initialSegment: ReservationSegment? = nil
    ) {
        self.initialSegment = initialSegment
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReservationDesignTokens.sectionSpacing) {
                    ReservationSegmentControl(
                        selectedSegment: viewModel.selectedSegment,
                        onSelect: handleSegmentSelection
                    )
                        .padding(.top, 8)

                    switch viewModel.selectedSegment {
                    case .upcoming:
                        upcomingSection
                    case .past:
                        pastSection
                    }
                }
                .padding(.horizontal, ReservationDesignTokens.horizontalPadding)
                .padding(.bottom, 30)
            }
            .background(ReservationDesignTokens.screenBackground.ignoresSafeArea())
            .navigationTitle("내 예약 관리")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            configureRepository()
            if let initialSegment {
                viewModel.selectSegment(initialSegment)
            }
            viewModel.onAppear()
        }
        .onChange(of: appViewModel.session?.accessToken) { _, _ in
            configureRepository()
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reservationCreated)) { _ in
            viewModel.refresh()
        }
        .sheet(item: $viewModel.route) { route in
            ReservationPlaceholderSheetView(
                route: route,
                onTapClose: viewModel.dismissRoute
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.visible)
        }
        .alert("안내", isPresented: isAlertPresented) {
            Button("확인") {
                viewModel.clearAlertMessage()
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private func handleSegmentSelection(_ segment: ReservationSegment) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            viewModel.selectSegment(segment)
        }
    }

    private func configureRepository() {
        if appViewModel.session != nil {
            viewModel.bind(repository: ReservationAPIRepository(service: appViewModel))
        } else {
            viewModel.bind(repository: ReservationMockRepository())
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("나의 방문 예정")

            if let nextReservation = viewModel.upcoming.first {
                UpcomingReservationCardView(
                    reservation: nextReservation,
                    imageName: ReservationDesignTokens.defaultUpcomingImageName,
                    onTapChange: { viewModel.tapChangeReservation(nextReservation) },
                    onTapDirections: { viewModel.tapDirections(nextReservation) }
                )
                .equatable()

                if viewModel.upcoming.count > 1 {
                    Text("외 \(viewModel.upcoming.count - 1)건의 예약이 더 있어요")
                        .font(.footnote)
                        .foregroundStyle(ReservationDesignTokens.secondaryText)
                }
            } else if viewModel.isLoading {
                loadingCard(message: "다가올 예약을 불러오는 중이에요.")
            } else {
                emptyCard(
                    title: "다가오는 예약이 없어요",
                    message: "피드에서 마음에 드는 디자인을 고르고 예약해 보세요."
                )
            }
        }
    }

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("지난 방문 기록")

            if viewModel.past.isEmpty, viewModel.isLoading {
                loadingCard(message: "지난 예약을 불러오는 중이에요.")
            } else if viewModel.past.isEmpty {
                emptyCard(
                    title: "지난 방문 기록이 없어요",
                    message: "첫 예약을 완료하면 이곳에 기록이 쌓여요."
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.past) { reservation in
                        PastReservationCardView(
                            reservation: reservation,
                            onTapReview: {
                                guard reservation.reviewStatus.isEnabled else { return }
                                viewModel.tapWriteReview(reservation)
                            }
                        )
                        .equatable()
                    }
                }

                if viewModel.isLoadingMore {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("지난 예약을 더 불러오는 중")
                            .font(.footnote)
                            .foregroundStyle(ReservationDesignTokens.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else if viewModel.hasMorePast {
                    Button {
                        viewModel.loadMorePastIfNeeded(currentItem: nil)
                    } label: {
                        Label("더보기", systemImage: "chevron.down")
                            .font(.headline)
                            .foregroundStyle(ReservationDesignTokens.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("reservation.past.loadMore")
                }
            }
        }
    }

    private func loadingCard(message: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(ReservationDesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(ReservationDesignTokens.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous)
                .stroke(ReservationDesignTokens.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous))
    }

    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearAlertMessage()
                }
            }
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(ReservationDesignTokens.sectionTitleText)
    }

    private func emptyCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ReservationDesignTokens.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(ReservationDesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ReservationDesignTokens.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous)
                .stroke(ReservationDesignTokens.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous))
    }
}

private struct ReservationPlaceholderSheetView: View {
    let route: ReservationRoute
    let onTapClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "hammer.circle")
                .appTypography(size: 28)
                .foregroundStyle(ReservationDesignTokens.accent)

            Text(route.title)
                .font(.title3.weight(.bold))

            Text(route.placeholderMessage)
                .font(.subheadline)
                .foregroundStyle(ReservationDesignTokens.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button("확인") {
                onTapClose()
            }
            .buttonStyle(.borderedProminent)
            .tint(ReservationDesignTokens.accent)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
}

#Preview("예약 관리") {
    ReservationManagementView(initialSegment: .upcoming)
        .environmentObject(AppViewModel())
}
