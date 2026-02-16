//
//  ProfileEditSheetView.swift
//  NailClient
//

import SwiftUI
import UIKit

struct ProfileEditSheetView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var viewModel: ProfileViewModel

    @FocusState private var focusedField: Field?
    @State private var didAttemptSave: Bool = false

    private enum Field: Hashable {
        case nickname
        case phone
    }

    var body: some View {
        NavigationStack {
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

                labeledTextField(
                    title: "휴대폰 번호",
                    placeholder: "010-0000-0000",
                    text: $viewModel.phone,
                    field: .phone,
                    keyboardType: .phonePad,
                    errorMessage: viewModel.phoneValidationMessage,
                    showError: didAttemptSave || !viewModel.phone.isEmpty
                )

                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        viewModel.isEditSheetPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        submit()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("저장")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!viewModel.isSaveEnabled)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
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
                .submitLabel(field == .nickname ? .next : .done)
                .onSubmit {
                    if field == .nickname {
                        focusedField = .phone
                    } else {
                        submit()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
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
        guard viewModel.nicknameValidationMessage == nil, viewModel.phoneValidationMessage == nil else {
            return
        }

        focusedField = nil
        Task {
            await viewModel.save(appViewModel: appViewModel)
        }
    }
}

#Preview {
    ProfileEditSheetView(viewModel: ProfileViewModel())
        .environmentObject(AppViewModel())
}
