import Testing
@testable import NailClient

final class SettingsConsentStoreSpy: AITransferConsentStoring {
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
final class SettingsServiceSpy: SettingsServicing {
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
