//
//  ProfileDraftView.swift
//  NailClient
//

import SwiftUI

struct ProfileDraftView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert: Bool = false

    private let menuItems: [(icon: String, item: ProfileViewModel.ComingSoonItem)] = [
        ("heart.text.square", .likedDesigns),
        ("creditcard", .paymentMethods),
        ("giftcard", .couponsAndPoints),
        ("questionmark.circle", .support)
    ]

    private var displayName: String {
        let nickname = appViewModel.currentUser?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        return "닉네임 미설정"
    }

    private var displayPhone: String {
        let phone = appViewModel.currentUser?.phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let phone, !phone.isEmpty {
            return phone
        }
        return "전화번호 미등록"
    }

    private var profileImageURL: URL? {
        guard
            let raw = appViewModel.currentUser?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        return URL(string: raw)
    }

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
        .onAppear {
            viewModel.sync(from: appViewModel.currentUser)
        }
        .onReceive(appViewModel.$currentUser) { newUser in
            viewModel.sync(from: newUser)
        }
        .sheet(isPresented: $viewModel.isEditSheetPresented) {
            ProfileEditSheetView(viewModel: viewModel)
                .environmentObject(appViewModel)
        }
        .sheet(item: $viewModel.comingSoonItem) { item in
            comingSoonSheet(item: item)
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
        }
        .alert("로그아웃", isPresented: $showSignOutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                Task { await appViewModel.signOut() }
            }
        } message: {
            Text("현재 계정에서 로그아웃할까요?")
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                profileImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                    Text(displayPhone)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)
            }

            Button("프로필 수정") {
                viewModel.beginEdit(from: appViewModel.currentUser)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var profileImage: some View {
        Group {
            if let profileImageURL {
                AsyncImage(url: profileImageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        profilePlaceholder
                    @unknown default:
                        profilePlaceholder
                    }
                }
            } else {
                profilePlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .background(Color(uiColor: .systemGray5), in: Circle())
        .clipShape(Circle())
    }

    private var profilePlaceholder: some View {
        Image(systemName: "person.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
    }

    private var menuCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                Button {
                    viewModel.showComingSoon(item.item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.body)
                            .frame(width: 22)
                            .foregroundStyle(.primary)

                        Text(item.item.rawValue)
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
                showSignOutAlert = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func comingSoonSheet(item: ProfileViewModel.ComingSoonItem) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(.orange)

            Text(item.rawValue)
                .font(.headline)

            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button("확인") {
                viewModel.closeComingSoon()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

#Preview {
    ProfileDraftView()
        .environmentObject(AppViewModel())
}
