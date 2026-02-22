//
//  OnboardingProfileStyleStepView.swift
//  NailClient
//
//  Created by Codex on 2/16/26.
//

import SwiftUI

struct OnboardingProfileStyleStepView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: OnboardingProfileViewModel

    private var primary: Color { LoginDesignTokens.primaryHTML }
    private var brandPrimary: Color { LoginDesignTokens.brandPrimary }

    var body: some View {
        ZStack {
            // iOS 26 Liquid Glass needs content behind it to refract.
            LoginBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("마지막으로 선호하는 스타일을 선택해요")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Color(.secondaryLabel))
                        .padding(.top, 6)

                    styleSection

                    ctaSection
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("선호 스타일")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            Task {
                await appViewModel.refreshOnboardingStyleAssets()
            }
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("선호하는 스타일")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : Color(.label))

                Spacer()

                Text("\(viewModel.selectedStyles.count)/3")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primary)
            }

            Text("좋아하는 무드를 카드에서 최대 3개까지 선택해 주세요")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color(.secondaryLabel))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(OnboardingProfileViewModel.PreferredStyle.allCases) { style in
                    let isSelected = viewModel.selectedStyles.contains(style)
                    styleCard(style: style, isSelected: isSelected)
                }
            }
        }
    }

    private func styleCard(style: OnboardingProfileViewModel.PreferredStyle, isSelected: Bool) -> some View {
        Button {
            viewModel.toggleStyle(style)
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .overlay {
                        styleBackground(for: style)
                    }
                    .overlay {
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.58)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(alignment: .bottomLeading) {
                        Text(style.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .lineSpacing(1.5)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? brandPrimary.opacity(0.95)
                            : (colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.08)),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(style.rawValue) 선택 해제" : "\(style.rawValue) 선택")
    }

    @ViewBuilder
    private func styleBackground(for style: OnboardingProfileViewModel.PreferredStyle) -> some View {
        if let remoteURL = appViewModel.onboardingStyleImageURLs[style.styleKey] {
            NailRemoteImage(
                url: remoteURL,
                targetSize: CGSize(width: 220, height: 220),
                resizeMode: .fill
            ) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackBackground(for: style)
                case .empty:
                    ZStack {
                        fallbackBackground(for: style)
                        ProgressView()
                            .tint(.white)
                    }
                @unknown default:
                    fallbackBackground(for: style)
                }
            }
        } else {
            fallbackBackground(for: style)
        }
    }

    private func fallbackBackground(for style: OnboardingProfileViewModel.PreferredStyle) -> some View {
        LinearGradient(
            colors: fallbackGradient(for: style),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "photo")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.48))
        }
    }

    private func fallbackGradient(for style: OnboardingProfileViewModel.PreferredStyle) -> [Color] {
        switch style {
        case .officeMinimal:
            return [Color(hex: 0x6D7D8B), Color(hex: 0xA8B3BD), Color(hex: 0x2F3C47)]
        case .natural:
            return [Color(hex: 0xAF8D6A), Color(hex: 0xE5C9A4), Color(hex: 0x6A4E2E)]
        case .lovelyCute:
            return [Color(hex: 0xFF8BA7), Color(hex: 0xFFC6D2), Color(hex: 0xD85A82)]
        case .hipStreet:
            return [Color(hex: 0x514C8A), Color(hex: 0x7C6BD1), Color(hex: 0x181B40)]
        case .chicModern:
            return [Color(hex: 0x4E5A6A), Color(hex: 0x9AA4B1), Color(hex: 0x1E2530)]
        case .kitschUnique:
            return [Color(hex: 0xE56AA6), Color(hex: 0xFFB84C), Color(hex: 0x5932D7)]
        case .glitterPearl:
            return [Color(hex: 0xD8D3FF), Color(hex: 0xFFEAF7), Color(hex: 0xAFA0EC)]
        case .french:
            return [Color(hex: 0xF6D8D8), Color(hex: 0xFFF8EE), Color(hex: 0xB98989)]
        case .gradationOmbre:
            return [Color(hex: 0x7B8DFF), Color(hex: 0xBCA6FF), Color(hex: 0x3842AA)]
        case .wedding:
            return [Color(hex: 0xE8D8BC), Color(hex: 0xFFF9F0), Color(hex: 0xB7A07B)]
        case .seasonHoliday:
            return [Color(hex: 0xCC3A5B), Color(hex: 0xFF885B), Color(hex: 0x2C7558)]
        case .pointArt:
            return [Color(hex: 0x4A52A5), Color(hex: 0x58B5D7), Color(hex: 0xF0934D)]
        }
    }

    private var ctaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await viewModel.submit(appViewModel: appViewModel) }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isSubmitting {
                        ProgressView()
                    }
                    Text("오늘 네일하러 가기")
                        .font(.system(size: 18, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.glassProminent)
            .tint(viewModel.isSubmitEnabled ? brandPrimary : (colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.12)))
            .disabled(!viewModel.isSubmitEnabled)
            .opacity(viewModel.isSubmitEnabled ? 1.0 : 0.55)

            if let noticeMessage = viewModel.photoUploadNoticeMessage, !noticeMessage.isEmpty {
                Text(noticeMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.yellow.opacity(0.95) : Color.orange)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingProfileStyleStepView(viewModel: OnboardingProfileViewModel())
            .environmentObject(AppViewModel())
    }
}
