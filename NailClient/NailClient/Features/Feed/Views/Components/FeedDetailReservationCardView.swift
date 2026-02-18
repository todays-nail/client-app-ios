import SwiftUI

struct FeedDetailReservationCardView: View {
    let selectedDate: Date
    let selectedSlot: ReservationSlotResponse?
    let slotsForSelectedDate: [ReservationSlotResponse]
    let isLoading: Bool
    let isClosed: Bool
    let errorMessage: String?
    let onTapDateTimeRow: () -> Void
    let onTapSlot: (ReservationSlotResponse) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("예약 가능 일정")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)

            Button(action: onTapDateTimeRow) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("날짜 • 시간")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FeedDesignTokens.detailSecondaryText)

                        Text(selectionSummaryText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FeedDesignTokens.detailSecondaryText)
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
            .buttonStyle(.plain)
            .accessibilityIdentifier("reservation.detail.card.summary.button")

            VStack(alignment: .leading, spacing: 8) {
                Text("해당 날짜 가능한 시간")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)

                timeSlotSection
            }
        }
        .accessibilityIdentifier("reservation.detail.card")
    }

    @ViewBuilder
    private var timeSlotSection: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                Text("예약 가능한 시간을 불러오는 중이에요.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        } else if let errorMessage, !errorMessage.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Button("다시 불러오기") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .tint(FeedDesignTokens.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        } else if isClosed {
            Text("해당 날짜는 휴무입니다.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        } else if slotsForSelectedDate.isEmpty {
            Text("선택한 날짜에 예약 가능한 시간이 없어요.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FeedDesignTokens.detailSecondaryText)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(slotsForSelectedDate, id: \.id) { slot in
                        let isSelected = selectedSlot?.id == slot.id

                        Button {
                            onTapSlot(slot)
                        } label: {
                            Text(Self.timeFormatter.string(from: slot.startAt))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : FeedDesignTokens.detailPrimaryText)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? FeedDesignTokens.accent : FeedDesignTokens.detailSubCardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            isSelected ? FeedDesignTokens.accent : FeedDesignTokens.detailBorder,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("reservation.detail.card.slot.\(slot.id.uuidString)")
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var selectionSummaryText: String {
        if let selectedSlot {
            return Self.slotFormatter.string(from: selectedSlot.startAt)
        }
        return "\(Self.dateFormatter.string(from: selectedDate)) • 시간 선택"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let slotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E) HH:mm"
        return formatter
    }()
}

#Preview {
    let dayStart = Calendar.current.startOfDay(for: Date())
    let sampleSlots = [
        ReservationSlotResponse(
            id: UUID(),
            shopId: UUID(),
            startAt: Calendar.current.date(byAdding: .minute, value: 600, to: dayStart) ?? dayStart,
            durationMin: 60,
            capacity: 1,
            status: "OPEN"
        ),
        ReservationSlotResponse(
            id: UUID(),
            shopId: UUID(),
            startAt: Calendar.current.date(byAdding: .minute, value: 660, to: dayStart) ?? dayStart,
            durationMin: 60,
            capacity: 1,
            status: "OPEN"
        )
    ]

    FeedDetailReservationCardView(
        selectedDate: dayStart,
        selectedSlot: sampleSlots.first,
        slotsForSelectedDate: sampleSlots,
        isLoading: false,
        isClosed: false,
        errorMessage: nil,
        onTapDateTimeRow: {},
        onTapSlot: { _ in },
        onRetry: {}
    )
    .padding()
    .background(FeedDesignTokens.detailBackground)
}
