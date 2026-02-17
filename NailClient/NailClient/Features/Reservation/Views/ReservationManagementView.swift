//
//  ReservationManagementView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct ReservationManagementView: View {
    @StateObject private var viewModel: ReservationViewModel
    @State private var shouldPushPastPage: Bool = false

    init() {
        _viewModel = StateObject(wrappedValue: ReservationViewModel())
    }

    init(viewModel: ReservationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReservationDesignTokens.sectionSpacing) {
                    ReservationSegmentControl(
                        selectedSegment: .upcoming,
                        onSelect: handleRootSegmentSelection
                    )
                        .padding(.top, 8)

                    if viewModel.isLoading, viewModel.upcoming.isEmpty, viewModel.past.isEmpty {
                        loadingSection
                    } else {
                        upcomingSection
                    }
                }
                .padding(.horizontal, ReservationDesignTokens.horizontalPadding)
                .padding(.bottom, 30)
            }
            .background(ReservationDesignTokens.screenBackground.ignoresSafeArea())
            .navigationTitle("내 예약 관리")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $shouldPushPastPage) {
                PastReservationPageView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.selectSegment(.upcoming)
            viewModel.onAppear()
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

    private var loadingSection: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("예약 정보를 불러오는 중이에요.")
                .font(.subheadline)
                .foregroundStyle(ReservationDesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private func handleRootSegmentSelection(_ segment: ReservationSegment) {
        switch segment {
        case .upcoming:
            viewModel.selectSegment(.upcoming)
        case .past:
            viewModel.selectSegment(.past)
            shouldPushPastPage = true
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

                if viewModel.upcoming.count > 1 {
                    Text("외 \(viewModel.upcoming.count - 1)건의 예약이 더 있어요")
                        .font(.footnote)
                        .foregroundStyle(ReservationDesignTokens.secondaryText)
                }
            } else {
                emptyCard(
                    title: "다가오는 예약이 없어요",
                    message: "피드에서 마음에 드는 디자인을 고르고 예약해 보세요."
                )
            }
        }
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
                .font(.system(size: 28))
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

#Preview {
    ReservationManagementView()
}
