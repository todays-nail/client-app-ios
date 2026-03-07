import Testing
@testable import NailClient

@MainActor
struct SettingsViewModelTests {
    @Test
    func syncConsentState_스토어상태를반영한다() {
        let consentStore = SettingsConsentStoreSpy(hasConsent: true)
        let viewModel = SettingsViewModel(consentStore: consentStore)

        viewModel.syncConsentState()

        #expect(viewModel.hasAITransferConsent == true)
    }

    @Test
    func revokeAITransferConsent_동의상태를해제한다() {
        let consentStore = SettingsConsentStoreSpy(hasConsent: true)
        let viewModel = SettingsViewModel(consentStore: consentStore)

        viewModel.revokeAITransferConsent()

        #expect(viewModel.hasAITransferConsent == false)
        #expect(consentStore.revokeCallCount == 1)
    }

    @Test
    func deleteMyAccount_실패시_에러메시지를노출한다() async {
        let consentStore = SettingsConsentStoreSpy(hasConsent: false)
        let service = SettingsServiceSpy(deleteResult: false, errorMessage: "탈퇴 실패")
        let viewModel = SettingsViewModel(consentStore: consentStore)
        viewModel.bind(service: service)

        await viewModel.deleteMyAccount()

        #expect(viewModel.isDeletingAccount == false)
        #expect(viewModel.deleteErrorMessage == "탈퇴 실패")
    }

    @Test
    func deleteMyAccount_성공시_에러메시지를남기지않는다() async {
        let consentStore = SettingsConsentStoreSpy(hasConsent: true)
        let service = SettingsServiceSpy(deleteResult: true, errorMessage: nil)
        let viewModel = SettingsViewModel(consentStore: consentStore)
        viewModel.bind(service: service)

        await viewModel.deleteMyAccount()

        #expect(viewModel.isDeletingAccount == false)
        #expect(viewModel.deleteErrorMessage == nil)
        #expect(service.deleteCallCount == 1)
    }
}

private final class SettingsConsentStoreSpy: AITransferConsentStoring {
    var hasConsent: Bool
    private(set) var revokeCallCount: Int = 0

    init(hasConsent: Bool) {
        self.hasConsent = hasConsent
    }

    func revokeConsent() {
        revokeCallCount += 1
        hasConsent = false
    }
}

@MainActor
private final class SettingsServiceSpy: SettingsServicing {
    var errorMessage: String?
    private let deleteResult: Bool
    private(set) var deleteCallCount: Int = 0

    init(deleteResult: Bool, errorMessage: String?) {
        self.deleteResult = deleteResult
        self.errorMessage = errorMessage
    }

    func deleteMyAccount(reason: String?) async -> Bool {
        _ = reason
        deleteCallCount += 1
        return deleteResult
    }
}
