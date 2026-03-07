//
//  SettingsViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
protocol SettingsServicing: AnyObject {
    var errorMessage: String? { get }

    func deleteMyAccount(reason: String?) async -> Bool
}

extension AppViewModel: SettingsServicing {}

protocol AITransferConsentStoring {
    var hasConsent: Bool { get }
    func revokeConsent()
}

extension AITransferConsentStore: AITransferConsentStoring {}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showDeleteConfirmAlert: Bool = false
    @Published var showDeleteFinalAlert: Bool = false
    @Published private(set) var isDeletingAccount: Bool = false
    @Published var deleteErrorMessage: String?
    @Published private(set) var hasAITransferConsent: Bool = false
    @Published var showRevokeConsentConfirmAlert: Bool = false

    private let consentStore: any AITransferConsentStoring
    private weak var service: (any SettingsServicing)?

    init(consentStore: (any AITransferConsentStoring)? = nil) {
        let resolvedConsentStore = consentStore ?? AITransferConsentStore.shared
        self.consentStore = resolvedConsentStore
        self.hasAITransferConsent = resolvedConsentStore.hasConsent
    }

    var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "v\(shortVersion) (\(buildVersion))"
    }

    func bind(service: any SettingsServicing) {
        self.service = service
    }

    func syncConsentState() {
        hasAITransferConsent = consentStore.hasConsent
    }

    func requestDeleteAccount() {
        showDeleteConfirmAlert = true
    }

    func requestDeleteAccountFinalConfirmation() {
        showDeleteFinalAlert = true
    }

    func dismissDeleteError() {
        deleteErrorMessage = nil
    }

    func requestConsentRevocation() {
        showRevokeConsentConfirmAlert = true
    }

    func revokeAITransferConsent() {
        consentStore.revokeConsent()
        hasAITransferConsent = false
    }

    func deleteMyAccount() async {
        guard !isDeletingAccount else { return }
        guard let service else {
            deleteErrorMessage = "회원 탈퇴를 준비하지 못했어요."
            return
        }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        let success = await service.deleteMyAccount(reason: nil)
        guard !success else { return }

        deleteErrorMessage = service.errorMessage ?? "회원 탈퇴 처리 중 문제가 발생했어요."
    }
}
