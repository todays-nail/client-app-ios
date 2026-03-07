//
//  ProfileEditSheetView.swift
//  NailClient
//

import SwiftUI
import UIKit

struct ProfileEditSheetView: View {
    @ObservedObject var viewModel: ProfileViewModel

    @FocusState private var focusedField: Field?
    @State private var didAttemptSave: Bool = false

    private enum Field: Hashable {
        case nickname
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: ProfileDesignTokens.editSheetCardSpacing) {
                    headerSection
                    formCard

                    if let saveErrorMessage = viewModel.saveErrorMessage {
                        Text(saveErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal, ProfileDesignTokens.editSheetContentPadding)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .background(ProfileDesignTokens.pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        viewModel.isEditSheetPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isEditSheetPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .appTypography(size: 14, weight: .semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButtonBar
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("프로필 수정")
                .font(.title3.weight(.bold))
                .foregroundStyle(ProfileDesignTokens.primaryText)

            Text("닉네임을 최신 정보로 유지해 주세요.")
                .font(.subheadline)
                .foregroundStyle(ProfileDesignTokens.secondaryText)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledTextField(
                title: "닉네임",
                placeholder: "닉네임을 입력해 주세요",
                text: $viewModel.nickname,
                field: .nickname,
                keyboardType: .default,
                errorMessage: viewModel.nicknameValidationMessage,
                showError: didAttemptSave || !viewModel.nickname.isEmpty
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignTokens.editSheetCardCornerRadius, style: .continuous)
                .fill(ProfileDesignTokens.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileDesignTokens.editSheetCardCornerRadius, style: .continuous)
                        .stroke(ProfileDesignTokens.cardBorder, lineWidth: 1)
                )
        )
    }

    private var saveButtonBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isSaving ? "저장 중..." : "저장하기")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.isSaveEnabled ? ProfileDesignTokens.accent : ProfileDesignTokens.sectionTitle)
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isSaveEnabled)
            .padding(.horizontal, ProfileDesignTokens.editSheetBottomInsetPadding)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemBackground))
    }

    @ViewBuilder
    private func labeledTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType,
        errorMessage: String?,
        showError: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: field)
                .submitLabel(.done)
                .onSubmit {
                    submit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, ProfileDesignTokens.editSheetFieldVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignTokens.editSheetFieldCornerRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

            if showError, let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func submit() {
        didAttemptSave = true
        guard viewModel.nicknameValidationMessage == nil else {
            return
        }

        focusedField = nil
        Task {
            await viewModel.save()
        }
    }
}

#Preview {
    ProfileEditSheetView(viewModel: ProfileViewModel())
}
