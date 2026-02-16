//
//  HomeSchedulePickerSheetView.swift
//  NailClient
//

import SwiftUI

struct HomeSchedulePickerSheetView: View {
    let dateOptions: [HomeViewModel.ReservationDateOption]
    let selectedDate: HomeViewModel.ReservationDateOption?
    let timeSlots: [Date]
    let selectedStartTime: Date?
    let selectedEndTime: Date?
    let onSelectDate: (HomeViewModel.ReservationDateOption) -> Void
    let onUpdateStartTime: (Date) -> Void
    let onUpdateEndTime: (Date) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HomeDesignTokens.scheduleSheetSectionSpacing) {
            headerSection
            dateSection
            timeSection

            Button("완료") {
                onDone()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(HomeDesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
            .accessibilityLabel("예약 일정 선택 완료")
        }
        .padding(.horizontal, HomeDesignTokens.scheduleSheetHorizontalPadding)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("예약 가능 일정")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(HomeDesignTokens.primaryText)

            Text(summaryText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HomeDesignTokens.unselectedChipText.opacity(0.75))
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("날짜")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HomeDesignTokens.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dateOptions) { option in
                        dateChip(option)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var timeSection: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("시작")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HomeDesignTokens.primaryText)

                Picker("시작 시간", selection: selectedStartTimeBinding) {
                    ForEach(timeSlots, id: \.self) { slot in
                        Text(Self.timeFormatter.string(from: slot)).tag(slot)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("종료")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HomeDesignTokens.primaryText)

                Picker("종료 시간", selection: selectedEndTimeBinding) {
                    ForEach(timeSlots, id: \.self) { slot in
                        Text(Self.timeFormatter.string(from: slot)).tag(slot)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: HomeDesignTokens.scheduleSheetPickerHeight)
    }

    private func dateChip(_ option: HomeViewModel.ReservationDateOption) -> some View {
        let isSelected = selectedDate == option

        return BaseChipContainer(style: HomeChipPreset.scheduleDate(selected: isSelected).style) {
            onSelectDate(option)
        } content: {
            VStack(spacing: 4) {
                Text(Self.dateDayFormatter.string(from: option.date))
                    .font(.system(size: 13, weight: .bold))
                Text(Self.weekdayFormatter.string(from: option.date))
                    .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var selectedStartTimeBinding: Binding<Date> {
        Binding(
            get: { selectedStartTime ?? timeSlots.first ?? Date() },
            set: { onUpdateStartTime($0) }
        )
    }

    private var selectedEndTimeBinding: Binding<Date> {
        Binding(
            get: {
                selectedEndTime
                    ?? timeSlots.dropFirst().first
                    ?? timeSlots.first
                    ?? Date()
            },
            set: { onUpdateEndTime($0) }
        )
    }

    private var summaryText: String {
        guard
            let selectedDate,
            let selectedStartTime,
            let selectedEndTime
        else {
            return "날짜와 시간을 선택해 주세요"
        }

        let dateText = Self.dateDayFormatter.string(from: selectedDate.date)
        let startText = Self.timeFormatter.string(from: selectedStartTime)
        let endText = Self.timeFormatter.string(from: selectedEndTime)
        return "\(dateText) \(startText)-\(endText)"
    }

    private static let dateDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
