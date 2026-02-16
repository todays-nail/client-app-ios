//
//  ReservationHistoryDraftView.swift
//  NailClient
//

import SwiftUI

struct ReservationHistoryDraftView: View {
    private struct ReservationItem: Identifiable {
        let id = UUID()
        let salonName: String
        let artistName: String
        let serviceName: String
        let dateText: String
        let timeText: String
        let status: String
        let statusColor: Color
    }

    private let upcomingReservations: [ReservationItem] = [
        ReservationItem(
            salonName: "헤이네일 강남점",
            artistName: "소연 디자이너",
            serviceName: "이달의 젤아트",
            dateText: "2월 20일 (목)",
            timeText: "오후 3:00",
            status: "예약 확정",
            statusColor: .blue
        ),
        ReservationItem(
            salonName: "로즈 네일 스튜디오",
            artistName: "하나 원장",
            serviceName: "웨딩 네일",
            dateText: "2월 27일 (목)",
            timeText: "오전 11:30",
            status: "대기중",
            statusColor: .orange
        )
    ]

    private let pastReservations: [ReservationItem] = [
        ReservationItem(
            salonName: "벨라 네일",
            artistName: "민지 디자이너",
            serviceName: "프렌치 젤",
            dateText: "2월 8일 (토)",
            timeText: "오후 1:00",
            status: "방문 완료",
            statusColor: .green
        ),
        ReservationItem(
            salonName: "네일 오브 데이",
            artistName: "예진 디자이너",
            serviceName: "시럽 네일",
            dateText: "1월 29일 (수)",
            timeText: "오후 6:30",
            status: "방문 완료",
            statusColor: .green
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    reservationSection(
                        title: "다가오는 예약",
                        caption: "총 \(upcomingReservations.count)건",
                        items: upcomingReservations
                    )

                    reservationSection(
                        title: "지난 예약",
                        caption: "총 \(pastReservations.count)건",
                        items: pastReservations
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("예약 내역")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func reservationSection(
        title: String,
        caption: String,
        items: [ReservationItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.salonName)
                                .font(.subheadline.weight(.semibold))
                            Text(item.artistName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        Text(item.status)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(item.statusColor.opacity(0.12), in: Capsule())
                    }

                    Text(item.serviceName)
                        .font(.callout)
                        .foregroundStyle(.primary)

                    Label("\(item.dateText) · \(item.timeText)", systemImage: "calendar")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

#Preview {
    ReservationHistoryDraftView()
}
