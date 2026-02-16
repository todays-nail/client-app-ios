//
//  ProfileDraftView.swift
//  NailClient
//

import SwiftUI

struct ProfileDraftView: View {
    let onTapSignOut: () -> Void

    private let menuItems: [(icon: String, title: String)] = [
        ("heart.text.square", "찜한 디자인"),
        ("creditcard", "결제 수단 관리"),
        ("giftcard", "쿠폰/포인트"),
        ("questionmark.circle", "고객센터")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileCard
                    menuCard
                    accountCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("김네일 님")
                    .font(.headline)
                Text("다음 예약 1건")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var menuCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                Button(action: { }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.body)
                            .frame(width: 22)
                            .foregroundStyle(.primary)

                        Text(item.title)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < menuItems.count - 1 {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("계정")
                .font(.headline)

            Button("로그아웃") {
                onTapSignOut()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ProfileDraftView(onTapSignOut: { })
}
