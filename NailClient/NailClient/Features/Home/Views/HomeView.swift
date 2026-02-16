//
//  HomeView.swift
//  NailClient
//

import SwiftUI

struct HomeView: View {
    let onTapFeed: () -> Void
    let onTapAI: () -> Void
    let onTapReservations: () -> Void

    init(
        onTapFeed: @escaping () -> Void = {},
        onTapAI: @escaping () -> Void = {},
        onTapReservations: @escaping () -> Void = {}
    ) {
        self.onTapFeed = onTapFeed
        self.onTapAI = onTapAI
        self.onTapReservations = onTapReservations
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    welcomeCard
                    aiIntroCard
                    actionButtons
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("환영해요")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text("오늘의 취향에 맞는 네일을 바로 찾아보고 예약까지 이어가세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var aiIntroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI 기능 소개", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("손 사진과 원하는 스타일 설명으로 네일 디자인 시안을 생성할 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("AI로 네일 디자인 만들기") {
                onTapAI()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onTapFeed()
            } label: {
                actionRow(title: "피드 보러가기", systemImage: "square.grid.2x2")
            }

            Button {
                onTapReservations()
            } label: {
                actionRow(title: "예약 내역 보기", systemImage: "calendar")
            }
        }
    }

    private func actionRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    HomeView()
}
