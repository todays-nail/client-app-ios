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
                VStack(spacing: 20) {
                    trendExploreCard
                    aiFittingCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color(hex: 0xF9F9F8).ignoresSafeArea())
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var trendExploreCard: some View {
        Button(action: onTapFeed) {
            ZStack(alignment: .bottomLeading) {
                Image("home_trend_card_bg")
                    .resizable()
                    .scaledToFill()

                LinearGradient(
                    colors: [
                        .black.opacity(0.72),
                        .black.opacity(0.26),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Trend")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.20), in: Capsule())

                    Text("디자인 탐색")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text("트렌디한 네일 아트를 발견하고\n나만의 스타일을 찾아보세요.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.84))

                    HStack(spacing: 4) {
                        Text("자세히 보기")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                }
                .padding(26)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var aiFittingCard: some View {
        Button(action: onTapAI) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFF5F5), .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color(hex: 0xE85B4E).opacity(0.14), lineWidth: 1)
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 132, weight: .light))
                    .foregroundStyle(Color(hex: 0xE85B4E).opacity(0.11))
                    .padding(.trailing, 18)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xE85B4E).opacity(0.12))
                        Image(systemName: "camera.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xE85B4E))
                    }
                    .frame(width: 56, height: 56)

                    Spacer()

                    Text("AI 가상 피팅")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color(hex: 0x222222))

                    Text("내 손 사진 한 장으로\n퍼스널 컬러와 디자인을 매칭해보세요.")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0x6B6B6B))
                        .padding(.top, 6)

                    HStack(spacing: 6) {
                        Text("지금 시작하기")
                        Image(systemName: "arrow.right")
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: 0xE85B4E), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 22)
                }
                .padding(26)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
}
