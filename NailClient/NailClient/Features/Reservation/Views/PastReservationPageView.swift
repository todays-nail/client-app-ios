//
//  PastReservationPageView.swift
//  NailClient
//

import SwiftUI

@MainActor
struct PastReservationPageView: View {
    @ObservedObject var viewModel: ReservationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReservationDesignTokens.sectionSpacing) {
                ReservationSegmentControl(
                    selectedSegment: .past,
                    onSelect: handleSegmentSelection
                )
                .padding(.top, 8)

                Text("지난 예약")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ReservationDesignTokens.sectionTitleText)
                    .accessibilityIdentifier("reservation.page.past.title")

                pastSection
            }
            .padding(.horizontal, ReservationDesignTokens.horizontalPadding)
            .padding(.bottom, 30)
        }
        .background(ReservationDesignTokens.screenBackground.ignoresSafeArea())
        .navigationTitle("지난 예약")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectSegment(.past)
            viewModel.onAppear()
        }
    }

    private func handleSegmentSelection(_ segment: ReservationSegment) {
        switch segment {
        case .upcoming:
            viewModel.selectSegment(.upcoming)
            dismiss()
        case .past:
            viewModel.selectSegment(.past)
        }
    }

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("지난 방문 기록")

            if viewModel.past.isEmpty {
                emptyCard(
                    title: "지난 방문 기록이 없어요",
                    message: "첫 예약을 완료하면 이곳에 기록이 쌓여요."
                )
            } else {
                ForEach(viewModel.past) { reservation in
                    PastReservationCardView(
                        reservation: reservation,
                        onTapReview: {
                            guard reservation.reviewStatus.isEnabled else { return }
                            viewModel.tapWriteReview(reservation)
                        }
                    )
                    .onAppear {
                        viewModel.loadMorePastIfNeeded(currentItem: reservation)
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
        .clipShape(
            RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous)
        )
    }
}

#Preview {
    NavigationStack {
        PastReservationPageView(viewModel: ReservationViewModel())
    }
}
