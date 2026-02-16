//
//  ProfileViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    enum ComingSoonItem: String, Identifiable, CaseIterable {
        case likedDesigns = "찜한 디자인"
        case paymentMethods = "결제 수단 관리"
        case couponsAndPoints = "쿠폰/포인트"
        case support = "고객센터"

        var id: String { rawValue }

        var description: String {
            "\(rawValue) 기능은 곧 제공될 예정이에요."
        }
    }

    @Published var nickname: String = ""
    @Published var phone: String = ""
    @Published var isEditSheetPresented: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var saveErrorMessage: String?
    @Published var comingSoonItem: ComingSoonItem?

    private var originalNickname: String = ""
    private var originalPhone: String = ""

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPhone: String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var phoneDigits: String {
        phone.filter(\.isNumber)
    }

    var nicknameValidationMessage: String? {
        guard !trimmedNickname.isEmpty else {
            return "닉네임을 입력해 주세요."
        }

        let pattern = "^[가-힣A-Za-z0-9_]{2,12}$"
        guard trimmedNickname.range(of: pattern, options: .regularExpression) != nil else {
            return "닉네임은 2~12자, 한/영/숫자/_만 사용할 수 있어요."
        }
        return nil
    }

    var phoneValidationMessage: String? {
        guard !phoneDigits.isEmpty else { return nil }

        let pattern = "^01[016789]\\d{7,8}$"
        guard phoneDigits.range(of: pattern, options: .regularExpression) != nil else {
            return "휴대폰 번호 형식이 올바르지 않아요. 예: 010-1234-5678"
        }
        return nil
    }

    var hasChanges: Bool {
        trimmedNickname != originalNickname || trimmedPhone != originalPhone
    }

    var isSaveEnabled: Bool {
        !isSaving
        && nicknameValidationMessage == nil
        && phoneValidationMessage == nil
        && hasChanges
    }

    func sync(from user: AppUser?) {
        let normalizedNickname = user?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedPhone = user?.phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        originalNickname = normalizedNickname
        originalPhone = normalizedPhone

        nickname = normalizedNickname
        phone = normalizedPhone
        saveErrorMessage = nil
    }

    func beginEdit(from user: AppUser?) {
        sync(from: user)
        isEditSheetPresented = true
    }

    func closeComingSoon() {
        comingSoonItem = nil
    }

    func showComingSoon(_ item: ComingSoonItem) {
        comingSoonItem = item
    }

    func save(appViewModel: AppViewModel) async {
        guard isSaveEnabled else { return }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let success = await appViewModel.updateMyProfile(
            nickname: trimmedNickname,
            phone: trimmedPhone.isEmpty ? nil : trimmedPhone
        )

        if success {
            originalNickname = trimmedNickname
            originalPhone = trimmedPhone
            isEditSheetPresented = false
            return
        }

        saveErrorMessage = appViewModel.errorMessage ?? "프로필 수정에 실패했어요."
    }
}
