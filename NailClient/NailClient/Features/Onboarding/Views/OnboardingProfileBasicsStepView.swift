//
//  OnboardingProfileBasicsStepView.swift
//  NailClient
//
//  Created by Codex on 2/16/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct OnboardingProfileBasicsStepView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: OnboardingProfileViewModel
    let onSignOut: () -> Void
    let onNext: () -> Void

    @FocusState private var focusedField: Field?
    @State private var didAttemptNext: Bool = false

    private enum Field: Hashable {
        case nickname
    }

    private var primary: Color { LoginDesignTokens.primaryHTML }

    var body: some View {
        ZStack {
            // iOS 26 Liquid Glass needs content behind it to refract.
            LoginBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("간단한 정보만 입력하면 바로 시작할 수 있어요")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Color(.secondaryLabel))
                        .padding(.top, 6)

                    profilePhotoSection

                    inputSection

                    ctaSection
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
                    onSignOut()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("로그아웃")
                .buttonStyle(.plain)
            }
        }
    }

    private var profilePhotoSection: some View {
        let profileUIImage = viewModel.profileUIImage
        let prefilledProfileImageURL = viewModel.prefilledProfileImageURL
        let isLoadingPhoto = viewModel.isLoadingPhoto

        return VStack(spacing: 10) {
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 124, height: 124)
                        .glassEffect(.regular.interactive(false), in: Circle())

                    if let profileUIImage {
                        Image(uiImage: profileUIImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 124, height: 124)
                            .clipShape(Circle())
                    } else if let prefilledProfileImageURL {
                        NailRemoteImage(
                            url: prefilledProfileImageURL,
                            targetSize: CGSize(width: 124, height: 124),
                            resizeMode: .fill
                        ) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 124, height: 124)
                                    .clipShape(Circle())
                            case .empty:
                                ProgressView()
                            case .failure:
                                photoPlaceholder
                            @unknown default:
                                photoPlaceholder
                            }
                        }
                    } else {
                        photoPlaceholder
                    }

                    if isLoadingPhoto {
                        ProgressView()
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.hasProfilePhoto ? "프로필 사진 변경" : "프로필 사진 추가")

            Text(viewModel.hasProfilePhoto ? "사진 변경" : "사진 추가")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.74) : Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
        .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await viewModel.loadSelectedPhoto(newItem) }
        }
    }

    private var photoPlaceholder: some View {
        Image(systemName: "plus")
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.75))
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            labeledTextField(
                label: "닉네임",
                placeholder: "닉네임을 입력해주세요",
                text: $viewModel.nickname,
                field: .nickname,
                keyboardType: .default,
                textContentType: .nickname,
                errorMessage: viewModel.nicknameValidationMessage,
                showError: didAttemptNext || !viewModel.nickname.isEmpty
            )
        }
    }

    private var ctaSection: some View {
        Button {
            moveToNextStep()
        } label: {
            Text("다음")
                .font(.system(size: 18, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.glassProminent)
        .tint(LoginDesignTokens.brandPrimary)
        .disabled(!viewModel.isBasicsStepValid)
        .opacity(viewModel.isBasicsStepValid ? 1.0 : 0.55)
    }

    @ViewBuilder
    private func labeledTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType?,
        errorMessage: String?,
        showError: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Color(.tertiaryLabel))
                .tracking(0.8)
                .padding(.leading, 4)

            TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.45) : Color(.tertiaryLabel))
            )
            .textInputAutocapitalization(.never)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .focused($focusedField, equals: field)
            .submitLabel(.done)
            .onSubmit {
                handleFieldSubmit(field)
            }
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

            if showError, let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var fieldBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.04)
    }

    private func inputBorder(for field: Field) -> Color {
        if focusedField == field {
            return primary
        }
        return colorScheme == .dark ? Color.white.opacity(0.30) : Color.black.opacity(0.10)
    }

    private func handleFieldSubmit(_ field: Field) {
        _ = field
        moveToNextStep()
    }

    private func moveToNextStep() {
        didAttemptNext = true
        guard viewModel.isBasicsStepValid else { return }
        focusedField = nil
        onNext()
    }
}

#Preview {
    NavigationStack {
        OnboardingProfileBasicsStepView(
            viewModel: OnboardingProfileViewModel(),
            onSignOut: {},
            onNext: {}
        )
    }
}
