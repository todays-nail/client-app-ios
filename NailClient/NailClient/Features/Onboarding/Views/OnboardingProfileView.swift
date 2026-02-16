//
//  OnboardingProfileView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct OnboardingProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel = OnboardingProfileViewModel()

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case nickname
        case phone
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // iOS 26 Liquid Glass needs content behind it to refract.
                LoginBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("간단한 정보만 입력하면 바로 시작할 수 있어요")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color(.secondaryLabel))
                            .padding(.top, 6)

                        formCard
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("프로필 설정")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await appViewModel.signOut() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("로그아웃")
                    .buttonStyle(.plain)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedField = nil }
                }
            }
            .alert(
                "오류",
                isPresented: Binding(
                    get: { appViewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { appViewModel.errorMessage = nil }
                    }
                )
            ) {
                Button("확인", role: .cancel) { appViewModel.errorMessage = nil }
            } message: {
                Text(appViewModel.errorMessage ?? "")
            }
            .alert("사진 불러오기 실패", isPresented: $viewModel.showPhotoLoadErrorAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.photoLoadErrorMessage ?? "알 수 없는 오류가 발생했어요.")
            }
            .alert("최대 3개까지 선택", isPresented: $viewModel.showMaxStyleAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("선호하는 스타일은 최대 3개까지 선택할 수 있어요.")
            }
        }
    }

    private var primary: Color { LoginDesignTokens.primaryHTML }
    private var brandPrimary: Color { LoginDesignTokens.brandPrimary }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            profileRow

            inputSection

            styleSection

            ctaSection
        }
        .padding(20)
        .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var profileRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(false), in: Circle())

                if let profileUIImage = viewModel.profileUIImage {
                    Image(uiImage: profileUIImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .opacity(0.70)
                }

                if viewModel.isLoadingPhoto {
                    ProgressView()
                }
            }
            .accessibilityLabel("프로필 사진")

            VStack(alignment: .leading, spacing: 4) {
                Text("프로필 사진")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color(.label))

                Text(viewModel.profileUIImage == nil ? "사진 추가" : "사진 변경")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color(.secondaryLabel))
            }

            Spacer(minLength: 0)

            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("사진 선택")
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await viewModel.loadSelectedPhoto(newItem) }
        }
    }

    private var inputSection: some View {
        VStack(spacing: 18) {
            labeledTextField(
                label: "닉네임",
                placeholder: "닉네임을 입력해주세요",
                text: $viewModel.nickname,
                field: .nickname,
                keyboardType: .default,
                textContentType: .nickname
            )

            labeledTextField(
                label: "휴대폰 번호",
                placeholder: "010-0000-0000",
                text: $viewModel.phone,
                field: .phone,
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )
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
        VStack(spacing: 0) {
            Button {
                focusedField = nil
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

    @ViewBuilder
    private func labeledTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color(.tertiaryLabel))
                .tracking(0.8)
                .padding(.leading, 4)

            TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color(.tertiaryLabel))
            )
            .textInputAutocapitalization(.never)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fieldBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(inputBorder(for: field), lineWidth: focusedField == field ? 1.5 : 1)
            }
            .foregroundStyle(colorScheme == .dark ? Color.white : Color(.label))
            .font(.system(size: 15, weight: .medium))
        }
    }

    private var fieldBackground: Color {
        // Keep fields simple; the card itself provides the Liquid Glass surface.
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }

    private func inputBorder(for field: Field) -> Color {
        if focusedField == field {
            return primary
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }
}

#Preview {
    OnboardingProfileView()
        .environmentObject(AppViewModel())
}
