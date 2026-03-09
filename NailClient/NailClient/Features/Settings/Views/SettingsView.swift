//
//  SettingsView.swift
//  NailClient
//

import SwiftUI
import NailUI

struct SettingsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.openURL) private var openURL

    @State private var showMailFallbackAlert: Bool = false
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        SettingsScreen(
            viewModel: viewModel,
            onOpenSupportMail: openSupportMail,
            onOpenURL: { openURL($0) }
        )
        .onAppear {
            viewModel.bind(service: appViewModel)
            viewModel.syncConsentState()
        }
        .alert("회원 탈퇴", isPresented: $viewModel.showDeleteConfirmAlert) {
            Button("취소", role: .cancel) { }
            Button("다음", role: .destructive) {
                viewModel.requestDeleteAccountFinalConfirmation()
            }
        } message: {
            Text("회원 탈퇴를 진행할까요?")
        }
        .alert("최종 확인", isPresented: $viewModel.showDeleteFinalAlert) {
            Button("취소", role: .cancel) { }
            Button("회원 탈퇴", role: .destructive) {
                Task {
                    await viewModel.deleteMyAccount()
                }
            }
        } message: {
            Text("탈퇴하면 계정을 다시 사용할 수 없어요.")
        }
        .alert(
            "탈퇴 실패",
            isPresented: Binding(
                get: { viewModel.deleteErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissDeleteError()
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                viewModel.dismissDeleteError()
            }
        } message: {
            Text(viewModel.deleteErrorMessage ?? "회원 탈퇴 처리 중 문제가 발생했어요.")
        }
        .alert("메일 앱을 열 수 없어요", isPresented: $showMailFallbackAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("고객센터 이메일: \(AppConfig.supportEmail)")
        }
        .alert("AI 데이터 전송 동의를 철회할까요?", isPresented: $viewModel.showRevokeConsentConfirmAlert) {
            Button("취소", role: .cancel) { }
            Button("철회", role: .destructive) {
                viewModel.revokeAITransferConsent()
            }
        } message: {
            Text("철회 후에는 AI 생성 시 다시 동의해야 합니다.")
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
}

private struct SettingsScreen: View {
    @ObservedObject var viewModel: SettingsViewModel
    let onOpenSupportMail: () -> Void
    let onOpenURL: (URL) -> Void

    var body: some View {
        List {
            Section("고객지원") {
                Button(action: onOpenSupportMail) {
                    rowLabel("고객센터 메일 보내기", trailing: AppConfig.supportEmail)
                }
                .buttonStyle(.plain)
            }

            if AppConfig.termsOfServiceURL != nil || AppConfig.privacyPolicyURL != nil {
                Section("약관 및 정책") {
                    if let termsURL = AppConfig.termsOfServiceURL {
                        Button {
                            onOpenURL(termsURL)
                        } label: {
                            rowLabel("이용약관")
                        }
                        .buttonStyle(.plain)
                    }

                    if let privacyURL = AppConfig.privacyPolicyURL {
                        Button {
                            onOpenURL(privacyURL)
                        } label: {
                            rowLabel("개인정보처리방침")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("AI 데이터 전송") {
                HStack {
                    Text("현재 동의 상태")
                    Spacer()
                    Text(viewModel.hasAITransferConsent ? "동의됨" : "미동의")
                        .foregroundStyle(.secondary)
                }

                if viewModel.hasAITransferConsent {
                    Button(role: .destructive) {
                        viewModel.requestConsentRevocation()
                    } label: {
                        rowLabel("AI 데이터 전송 동의 철회")
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("AI 생성 시점에 다시 동의할 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("앱 정보") {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(viewModel.appVersionText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("계정 관리") {
                Button(role: .destructive) {
                    viewModel.requestDeleteAccount()
                } label: {
                    HStack {
                        Text("회원 탈퇴")
                        Spacer()
                        if viewModel.isDeletingAccount {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }
                .disabled(viewModel.isDeletingAccount)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isDeletingAccount)
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
        .fullRowTapTarget(alignment: .leading)
    }
}

#if DEBUG
#Preview("동의됨") {
    NavigationStack {
        SettingsScreen(
            viewModel: .previewState(hasAITransferConsent: true),
            onOpenSupportMail: {},
            onOpenURL: { _ in }
        )
    }
}

#Preview("미동의") {
    NavigationStack {
        SettingsScreen(
            viewModel: .previewState(hasAITransferConsent: false),
            onOpenSupportMail: {},
            onOpenURL: { _ in }
        )
    }
}
#endif
