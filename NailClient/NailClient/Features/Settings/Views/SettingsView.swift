//
//  SettingsView.swift
//  NailClient
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.openURL) private var openURL

    @State private var showDeleteConfirmAlert: Bool = false
    @State private var showDeleteFinalAlert: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var deleteErrorMessage: String?
    @State private var showMailFallbackAlert: Bool = false

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "v\(shortVersion) (\(buildVersion))"
    }

    var body: some View {
        List {
            Section("고객지원") {
                Button {
                    openSupportMail()
                } label: {
                    rowLabel("고객센터 메일 보내기", trailing: AppConfig.supportEmail)
                }
                .buttonStyle(.plain)
            }

            if AppConfig.termsOfServiceURL != nil || AppConfig.privacyPolicyURL != nil {
                Section("약관 및 정책") {
                    if let termsURL = AppConfig.termsOfServiceURL {
                        Button {
                            openURL(termsURL)
                        } label: {
                            rowLabel("이용약관")
                        }
                        .buttonStyle(.plain)
                    }

                    if let privacyURL = AppConfig.privacyPolicyURL {
                        Button {
                            openURL(privacyURL)
                        } label: {
                            rowLabel("개인정보처리방침")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("앱 정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(appVersionText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("계정 관리") {
                Button(role: .destructive) {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack {
                        Text("회원 탈퇴")
                        Spacer()
                        if isDeletingAccount {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }
                .disabled(isDeletingAccount)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isDeletingAccount)
        .alert("회원 탈퇴", isPresented: $showDeleteConfirmAlert) {
            Button("취소", role: .cancel) { }
            Button("다음", role: .destructive) {
                showDeleteFinalAlert = true
            }
        } message: {
            Text("회원 탈퇴를 진행할까요?")
        }
        .alert("최종 확인", isPresented: $showDeleteFinalAlert) {
            Button("취소", role: .cancel) { }
            Button("회원 탈퇴", role: .destructive) {
                Task {
                    await deleteMyAccount()
                }
            }
        } message: {
            Text("탈퇴하면 계정을 다시 사용할 수 없어요.")
        }
        .alert(
            "탈퇴 실패",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteErrorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "회원 탈퇴 처리 중 문제가 발생했어요.")
        }
        .alert("메일 앱을 열 수 없어요", isPresented: $showMailFallbackAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("고객센터 이메일: \(AppConfig.supportEmail)")
        }
    }

    @ViewBuilder
    private func rowLabel(_ title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func openSupportMail() {
        let rawEmail = AppConfig.supportEmail
        let encodedEmail = rawEmail.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? rawEmail

        guard let url = URL(string: "mailto:\(encodedEmail)") else {
            showMailFallbackAlert = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                showMailFallbackAlert = true
            }
        }
    }

    private func deleteMyAccount() async {
        guard !isDeletingAccount else { return }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        let success = await appViewModel.deleteMyAccount(reason: nil)
        guard !success else { return }

        deleteErrorMessage = appViewModel.errorMessage ?? "회원 탈퇴 처리 중 문제가 발생했어요."
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppViewModel())
    }
}
