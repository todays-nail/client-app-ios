//
//  ProfileDraftView.swift
//  NailClient
//

import SwiftUI

struct ProfileDraftView: View {
    private struct MenuRowItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let tint: Color
        let type: ProfileViewModel.ComingSoonItem
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutAlert: Bool = false

    private let activityItems: [MenuRowItem] = [
        .init(icon: "heart.fill", title: "찜한 디자인", tint: ProfileDesignTokens.accent, type: .likedDesigns),
        .init(icon: "sparkles", title: "내가 피팅한 AI 이미지", tint: ProfileDesignTokens.accent, type: .fittedAIImages)
    ]

    private let accountItems: [MenuRowItem] = [
        .init(icon: "creditcard.fill", title: "결제 수단 관리", tint: Color(hex: 0x5E687A), type: .paymentMethods),
        .init(icon: "gearshape.fill", title: "설정", tint: Color(hex: 0x5E687A), type: .settings)
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: ProfileDesignTokens.sectionSpacing) {
                    profileHeroSection
                    styleAnalysisCard
                    menuSection(title: "내 활동", items: activityItems)
                    menuSection(title: "계정 및 설정", items: accountItems)
                    logoutLinkButton
                }
                .padding(.horizontal, ProfileDesignTokens.horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("편집") {
                        viewModel.beginEdit(from: appViewModel.currentUser)
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ProfileDesignTokens.accent)
                }
            }
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

    private var profileHeroSection: some View {
        VStack(spacing: 14) {
            profileAvatar

            VStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 50, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(ProfileDesignTokens.primaryText)

                Text(displayPhone)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(ProfileDesignTokens.secondaryText)
            }

            Button("프로필 수정") {
                viewModel.beginEdit(from: appViewModel.currentUser)
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(ProfileDesignTokens.secondaryText)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
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
                            avatarPlaceholder
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 124, height: 124)
            .background(Color(hex: 0xF2C7A4), in: Circle())
            .overlay(
                Circle().stroke(Color.white, lineWidth: 5)
            )
            .clipShape(Circle())

            Button {
                viewModel.beginEdit(from: appViewModel.currentUser)
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(ProfileDesignTokens.accent, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .offset(x: 2, y: 2)
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 48))
            .foregroundStyle(Color.white.opacity(0.9))
    }

    private var styleAnalysisCard: some View {
        let summary = viewModel.styleInsightSummary

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("나의 스타일 분석")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(ProfileDesignTokens.primaryText)

                    Text(summary.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ProfileDesignTokens.secondaryText)
                }

                Spacer(minLength: 10)

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ProfileDesignTokens.accent)
                    .frame(width: 54, height: 54)
                    .background(Color(hex: 0xFCE9E5), in: Circle())
            }

            HStack(spacing: 16) {
                ringChart(ratio: summary.primaryRatio, rankText: summary.rankText)
                    .frame(width: 120, height: 120)

                VStack(spacing: 14) {
                    ForEach(summary.items) { item in
                        styleInsightRow(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignTokens.cardCornerRadius, style: .continuous)
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileDesignTokens.cardCornerRadius, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
        )
    }

    private func ringChart(ratio: Double, rankText: String) -> some View {
        let clampedRatio = max(0, min(1, ratio))

        return ZStack {
            Circle()
                .stroke(ProfileDesignTokens.mutedAccent.opacity(0.35), lineWidth: 11)

            Circle()
                .trim(from: 0, to: clampedRatio)
                .stroke(
                    ProfileDesignTokens.accent,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(rankText)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)
        }
    }

    private func styleInsightRow(_ item: ProfileViewModel.StyleInsightItem) -> some View {
        let ratio = max(0, min(1, item.ratio))
        let foregroundColor = item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.mutedAccent
        let textColor = item.emphasized ? ProfileDesignTokens.primaryText : ProfileDesignTokens.secondaryText

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(foregroundColor)
                    .frame(width: 10, height: 10)

                Text(item.tag)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(textColor)

                Spacer(minLength: 8)

                Text(item.percentageText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.emphasized ? ProfileDesignTokens.accent : ProfileDesignTokens.secondaryText)
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(ProfileDesignTokens.mutedAccent.opacity(0.35))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(foregroundColor)
                            .frame(width: proxy.size.width * ratio)
                    }
            }
            .frame(height: 10)
        }
    }

    private func menuSection(title: String, items: [MenuRowItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(ProfileDesignTokens.sectionTitle)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Button {
                        viewModel.showComingSoon(item.type)
                    } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item.tint.opacity(0.14))
                                .frame(width: 42, height: 42)
                                .overlay {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(item.tint)
                                }

                            Text(item.title)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(ProfileDesignTokens.primaryText)

                            Spacer(minLength: 10)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(ProfileDesignTokens.sectionTitle)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignTokens.groupedCardCornerRadius, style: .continuous)
                    .fill(ProfileDesignTokens.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: ProfileDesignTokens.groupedCardCornerRadius, style: .continuous)
                            .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var logoutLinkButton: some View {
        Button("로그아웃") {
            showSignOutAlert = true
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(ProfileDesignTokens.secondaryText)
        .underline()
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func comingSoonSheet(item: ProfileViewModel.ComingSoonItem) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(ProfileDesignTokens.accent)

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
            .tint(ProfileDesignTokens.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

#Preview {
    ProfileDraftView()
        .environmentObject(AppViewModel())
}
