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

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    ZStack {
                        Color.clear

                        ScrollView {
                            VStack(spacing: 0) {
                                profileSection

                                inputSection
                                    .padding(.top, 8)

                                styleSection
                                    .padding(.top, 24)
                                    .padding(.bottom, 24)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            topBar
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            bottomCTA
                        }
                    }
                    .frame(maxWidth: 420)
                    .frame(maxHeight: .infinity)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Spacer(minLength: 0)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
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

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    Task { await appViewModel.signOut() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Text("프로필 설정")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(colorScheme == .dark ? Color.white : Color(.label))
                .padding(.horizontal, 24)

            Text("간단한 정보만 입력하면 바로 시작할 수 있어요")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color(.secondaryLabel))
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 16)
        }
        .glassEffect(.regular.interactive(false), in: Rectangle())
    }

    private var profileSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 112, height: 112)
                    .glassEffect(.regular.interactive(false), in: Circle())
                    .overlay {
                        ZStack {
                            if let profileUIImage = viewModel.profileUIImage {
                                Image(uiImage: profileUIImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(Color(.secondaryLabel))
                                    .opacity(0.60)
                            }
                        }
                        .frame(width: 112, height: 112)
                        .clipShape(Circle())
                    }
                    .accessibilityLabel("프로필 사진")

                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: viewModel.isLoadingPhoto ? "hourglass" : "camera.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82))
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("사진 추가")
            }

            Text(viewModel.profileUIImage == nil ? "사진 추가" : "사진 변경")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 26)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("선호하는 스타일")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color(.label))
                    .textCase(.uppercase)

                Spacer()

                Text("최대 3개")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primary)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 12)

            FlowLayout(spacing: 8) {
                ForEach(OnboardingProfileViewModel.PreferredStyle.allCases) { style in
                    let isSelected = viewModel.selectedStyles.contains(style)
                    Group {
                        if isSelected {
                            Button {
                                viewModel.toggleStyle(style)
                            } label: {
                                Text(style.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.glassProminent)
                        } else {
                            Button {
                                viewModel.toggleStyle(style)
                            } label: {
                                Text(style.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
    }

    private var bottomCTA: some View {
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
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(false), in: Rectangle())
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
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(inputBorder(for: field), lineWidth: focusedField == field ? 2 : 1)
            }
            .shadow(color: focusShadow(for: field), radius: 10, x: 0, y: 4)
            .foregroundStyle(colorScheme == .dark ? Color.white : Color(.label))
            .font(.system(size: 15, weight: .medium))
        }
    }

    private func inputBorder(for field: Field) -> Color {
        if focusedField == field {
            return primary
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private func focusShadow(for field: Field) -> Color {
        guard focusedField == field else { return .clear }
        return primary.opacity(colorScheme == .dark ? 0.28 : 0.18)
    }
}

#Preview {
    OnboardingProfileView()
        .environmentObject(AppViewModel())
}
