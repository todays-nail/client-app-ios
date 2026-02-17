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
                        Image(styleAssetName(for: style))
                            .resizable()
                            .scaledToFill()
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

    private func styleAssetName(for style: OnboardingProfileViewModel.PreferredStyle) -> String {
        switch style {
        case .officeMinimal:
            return "office_minimal"
        case .natural:
            return "natural"
        case .lovelyCute:
            return "lovely"
        case .hipStreet:
            return "hip"
        case .chicModern:
            return "chic_modern"
        case .kitschUnique:
            return "kitsh_unique"
        case .glitterPearl:
            return "glitter_pearl"
        case .french:
            return "french"
        case .gradationOmbre:
            return "gradient_ombre"
        case .wedding:
            return "wedding"
        case .seasonHoliday:
            return "season_spring"
        case .pointArt:
            return "point-art"
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
