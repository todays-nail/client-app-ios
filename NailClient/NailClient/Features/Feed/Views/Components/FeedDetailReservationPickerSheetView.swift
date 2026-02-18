import SwiftUI

struct FeedDetailReservationPickerSheetView: View {
    @Binding var selectedDate: Date

    let dateRange: ClosedRange<Date>
    let slotsForSelectedDate: [ReservationSlotResponse]
    let selectedSlotID: UUID?
    let isLoading: Bool
    let isClosed: Bool
    let errorMessage: String?
    let onTapSlot: (ReservationSlotResponse) -> Void
    let onRetry: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("예약 날짜/시간 선택")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                    DatePicker(
                        "예약 날짜",
                        selection: $selectedDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .tint(FeedDesignTokens.accent)
                    .accessibilityIdentifier("reservation.detail.picker.datePicker")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("해당 날짜 가능한 시간")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                        timeSlotSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            Button("완료") {
                onDone()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(FeedDesignTokens.accent)
            )
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .presentationDragIndicator(.visible)
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
                        let isSelected = selectedSlotID == slot.id

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
                        .accessibilityIdentifier("reservation.detail.picker.slot.\(slot.id.uuidString)")
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    @Previewable @State var selectedDate = Calendar.current.startOfDay(for: Date())
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

    FeedDetailReservationPickerSheetView(
        selectedDate: $selectedDate,
        dateRange: dayStart...(Calendar.current.date(byAdding: .day, value: 6, to: dayStart) ?? dayStart),
        slotsForSelectedDate: sampleSlots,
        selectedSlotID: sampleSlots.first?.id,
        isLoading: false,
        isClosed: false,
        errorMessage: nil,
        onTapSlot: { _ in },
        onRetry: {},
        onDone: {}
    )
    .background(FeedDesignTokens.detailBackground)
}
