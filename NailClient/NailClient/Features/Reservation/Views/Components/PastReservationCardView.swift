//
//  PastReservationCardView.swift
//  NailClient
//

import SwiftUI

struct PastReservationCardView: View {
    let reservation: PastReservation
    let onTapReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reservation.salonName)
                        .font(.headline)
                        .foregroundStyle(ReservationDesignTokens.primaryText)

                    Text(dateText)
                        .font(.subheadline)
                        .foregroundStyle(ReservationDesignTokens.secondaryText)

                    tagRow
                }

                Spacer(minLength: 10)

                Image(reservation.thumbnailName)
                    .interpolation(.low)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button(action: onTapReview) {
                Text(reservation.reviewStatus.buttonTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(PastReviewButtonStyle(reviewStatus: reservation.reviewStatus))
            .disabled(!reservation.reviewStatus.isEnabled)
            .accessibilityLabel(reservation.reviewStatus.buttonTitle)
            .accessibilityIdentifier("reservation.past.review.button")
        }
        .padding(16)
        .background(ReservationDesignTokens.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous)
                .stroke(ReservationDesignTokens.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous))
    }

    private var tagRow: some View {
        HStack(spacing: 6) {
            ForEach(reservation.tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .foregroundStyle(ReservationDesignTokens.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ReservationDesignTokens.tagBackground, in: Capsule())
                    .lineLimit(1)
            }
        }
        .padding(.top, 2)
    }

    private var dateText: String {
        Self.dateFormatter.string(from: reservation.visitedAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        return formatter
    }()
}

extension PastReservationCardView: Equatable {
    static func == (lhs: PastReservationCardView, rhs: PastReservationCardView) -> Bool {
        lhs.reservation == rhs.reservation
    }
}

private struct PastReviewButtonStyle: ButtonStyle {
    let reviewStatus: ReviewStatus

    func makeBody(configuration: Configuration) -> some View {
        let isWritable = reviewStatus.isEnabled

        return configuration.label
            .font(.headline)
            .foregroundStyle(
                isWritable
                ? ReservationDesignTokens.accent
                : ReservationDesignTokens.secondaryText.opacity(0.8)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isWritable
                        ? ReservationDesignTokens.accent.opacity(configuration.isPressed ? 0.13 : 0.1)
                        : ReservationDesignTokens.completedButtonBackground
                    )
            )
    }
}

#Preview {
    PastReservationCardView(
        reservation: ReservationMockData.past().first!,
        onTapReview: {}
    )
    .padding()
    .background(ReservationDesignTokens.screenBackground)
}
