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
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color(.secondaryLabel))
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("로그아웃") {
                    Task { await appViewModel.signOut() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.80))
                .accessibilityLabel("로그아웃")
            }
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text("선호하는 스타일")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color(.label))

                Spacer()

                Text("\(viewModel.selectedStyles.count)/3")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primary)
            }

            FlowLayout(spacing: 6) {
                ForEach(OnboardingProfileViewModel.PreferredStyle.allCases) { style in
                    let isSelected = viewModel.selectedStyles.contains(style)
                    Button {
                        viewModel.toggleStyle(style)
                    } label: {
                        styleChip(title: style.rawValue, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func styleChip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
            .lineLimit(1)
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : (colorScheme == .dark ? Color.white.opacity(0.80) : Color(.secondaryLabel))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(brandPrimary)
                        .overlay {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .blendMode(.overlay)
                        }
                } else {
                    Color.clear
                        .glassEffect(.regular.interactive(false), in: Capsule(style: .continuous))
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? brandPrimary.opacity(0.25)
                            : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)),
                        lineWidth: 1
                    )
            }
            .contentShape(Capsule(style: .continuous))
            // Expand tap target without visually increasing chip size.
            .padding(.vertical, 2)
    }

    private var ctaSection: some View {
        Button {
            Task { await viewModel.submit(appViewModel: appViewModel) }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSubmitting {
                    ProgressView()
                }
                Text("시작하기")
                    .font(.system(size: 18, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.glassProminent)
        .disabled(!viewModel.isSubmitEnabled)
        .opacity(viewModel.isSubmitEnabled ? 1.0 : 0.55)
    }
}

#Preview {
    NavigationStack {
        OnboardingProfileStyleStepView(viewModel: OnboardingProfileViewModel())
            .environmentObject(AppViewModel())
    }
}

