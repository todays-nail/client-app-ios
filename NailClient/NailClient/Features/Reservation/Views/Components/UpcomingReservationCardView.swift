//
//  UpcomingReservationCardView.swift
//  NailClient
//

import SwiftUI

struct UpcomingReservationCardView: View {
    let reservation: UpcomingReservation
    let imageName: String
    let onTapChange: () -> Void
    let onTapDirections: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerImage

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(reservation.salonName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(ReservationDesignTokens.primaryText)

                        Label(reservation.address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(ReservationDesignTokens.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 10)

                    dDayBadge
                }

                divider

                HStack(alignment: .center, spacing: 12) {
                    dateTile

                    VStack(alignment: .leading, spacing: 4) {
                        Text(timeText)
                            .font(.headline)
                            .foregroundStyle(ReservationDesignTokens.primaryText)

                        Text("담당 디자이너: \(reservation.artistName)")
                            .font(.subheadline)
                            .foregroundStyle(ReservationDesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onTapChange) {
                        Text("예약 변경")
                            .frame(maxWidth: .infinity)
                            .frame(height: ReservationDesignTokens.ctaHeight)
                    }
                    .buttonStyle(OutlineCTAButtonStyle())
                    .accessibilityLabel("예약 변경")

                    Button(action: onTapDirections) {
                        Text("길찾기")
                            .frame(maxWidth: .infinity)
                            .frame(height: ReservationDesignTokens.ctaHeight)
                    }
                    .buttonStyle(FilledCTAButtonStyle())
                    .accessibilityLabel("길찾기")
                }
            }
            .padding(16)
        }
        .background(ReservationDesignTokens.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous)
                .stroke(ReservationDesignTokens.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ReservationDesignTokens.cardCornerRadius, style: .continuous))
    }

    private var headerImage: some View {
        ZStack(alignment: .topLeading) {
            Image(imageName)
                .interpolation(.low)
                .resizable()
                .scaledToFill()
                .frame(height: ReservationDesignTokens.heroImageHeight)
                .frame(maxWidth: .infinity)
                .clipped()

            if reservation.isAIFitting {
                Text("✦ AI 가상 피팅 이미지")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55), in: Capsule())
                    .padding(10)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(reservation.statusLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(ReservationDesignTokens.accent, in: Capsule())
                        .padding(12)
                }
            }
        }
    }

    private var dDayBadge: some View {
        Text(dDayText)
            .font(.footnote.weight(.bold))
            .foregroundStyle(ReservationDesignTokens.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ReservationDesignTokens.accent.opacity(0.12), in: Capsule())
    }

    private var dateTile: some View {
        VStack(spacing: 2) {
            Text(monthText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
            Text(dayText)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 68, height: 74)
        .background(
            ReservationDesignTokens.dateTileBackground,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(ReservationDesignTokens.cardBorder)
            .frame(height: 1)
    }

    private var dDayText: String {
        if reservation.dDay <= 0 {
            return "D-Day"
        }
        return "D-\(reservation.dDay)"
    }

    private var monthText: String {
        Self.monthFormatter.string(from: reservation.date)
    }

    private var dayText: String {
        Self.dayFormatter.string(from: reservation.date)
    }

    private var timeText: String {
        Self.timeFormatter.string(from: reservation.date)
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "EEEE a h:mm"
        return formatter
    }()
}

extension UpcomingReservationCardView: Equatable {
    static func == (lhs: UpcomingReservationCardView, rhs: UpcomingReservationCardView) -> Bool {
        lhs.reservation == rhs.reservation && lhs.imageName == rhs.imageName
    }
}

private struct FilledCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ReservationDesignTokens.accent.opacity(configuration.isPressed ? 0.85 : 1.0))
            )
    }
}

private struct OutlineCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(ReservationDesignTokens.accent)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ReservationDesignTokens.accent, lineWidth: 1.2)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ReservationDesignTokens.outlineButtonFill.opacity(configuration.isPressed ? 0.8 : 1.0))
                    )
            )
    }
}

#Preview {
    UpcomingReservationCardView(
        reservation: ReservationMockData.upcoming().first!,
        imageName: ReservationDesignTokens.defaultUpcomingImageName,
        onTapChange: {},
        onTapDirections: {}
    )
    .padding()
    .background(ReservationDesignTokens.screenBackground)
}
