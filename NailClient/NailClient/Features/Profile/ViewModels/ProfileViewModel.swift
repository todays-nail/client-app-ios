//
//  ProfileViewModel.swift
//  NailClient
//

import Foundation
import Combine

@MainActor
protocol ProfileServicing: AnyObject {
    var errorMessage: String? { get }

    func updateMyProfile(nickname: String) async -> Bool
    func uploadProfileImage(imageData: Data) async throws -> String
    func updateMyProfileImage(profileImageURL: String?) async -> Bool
}

extension AppViewModel: ProfileServicing {}

@MainActor
final class ProfileViewModel: ObservableObject {
    private static let profilePhotoUpdatedToastDefaultMessage = "프로필 사진이 변경되었어요."

    enum ComingSoonItem: String, Identifiable, CaseIterable {
        case likedDesigns = "찜한 디자인"
        case paymentMethods = "결제 수단 관리"
        case settings = "설정"
        case couponsAndPoints = "쿠폰/포인트"
        case support = "고객센터"

        var id: String { rawValue }

        var description: String {
            "\(rawValue) 기능은 곧 제공될 예정이에요."
        }
    }

    struct ProfileHeaderDisplay: Equatable {
        let name: String
        let profileImageURL: URL?
    }

    @Published var nickname: String = ""
    @Published var isEditSheetPresented: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var isUploadingProfilePhoto: Bool = false
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var profilePhotoToastMessage: String?
    @Published var profilePhotoErrorMessage: String?
    @Published var comingSoonItem: ComingSoonItem?

    private let profilePhotoToastDuration: Duration
    private weak var service: (any ProfileServicing)?
    private var profilePhotoToastDismissTask: Task<Void, Never>?

    private var originalNickname: String = ""

    init(profilePhotoToastDuration: Duration = .seconds(1.8)) {
        self.profilePhotoToastDuration = profilePhotoToastDuration
    }

    deinit {
        profilePhotoToastDismissTask?.cancel()
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
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

    var hasChanges: Bool {
        trimmedNickname != originalNickname
    }

    var isSaveEnabled: Bool {
        !isSaving
            && nicknameValidationMessage == nil
            && hasChanges
    }

    func bind(service: any ProfileServicing) {
        self.service = service
    }

    func makeHeaderDisplay(from user: AppUser?) -> ProfileHeaderDisplay {
        let trimmedName = user?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedURL = user?.profileImageURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let name = trimmedName.isEmpty ? "닉네임 미설정" : trimmedName
        let profileImageURL = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)

        return ProfileHeaderDisplay(
            name: name,
            profileImageURL: profileImageURL
        )
    }

    func sync(from user: AppUser?) {
        let normalizedNickname = user?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        originalNickname = normalizedNickname

        nickname = normalizedNickname
        saveErrorMessage = nil
    }

    func beginEdit(from user: AppUser?) {
        sync(from: user)
        isEditSheetPresented = true
    }

    func showProfilePhotoUpdatedToast() {
        profilePhotoToastDismissTask?.cancel()
        profilePhotoToastMessage = Self.profilePhotoUpdatedToastDefaultMessage

        let toastDuration = profilePhotoToastDuration
        profilePhotoToastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: toastDuration)
            guard !Task.isCancelled else { return }
            self?.clearProfilePhotoToast()
        }
    }

    func dismissProfilePhotoUpdatedToast() {
        profilePhotoToastDismissTask?.cancel()
        profilePhotoToastDismissTask = nil
        profilePhotoToastMessage = nil
    }

    func closeComingSoon() {
        comingSoonItem = nil
    }

    func showComingSoon(_ item: ComingSoonItem) {
        comingSoonItem = item
    }

    func uploadProfilePhoto(imageData: Data) async {
        guard !isUploadingProfilePhoto else { return }
        guard let service else {
            profilePhotoErrorMessage = "프로필 사진 변경을 준비하지 못했어요."
            return
        }

        isUploadingProfilePhoto = true
        profilePhotoErrorMessage = nil
        defer { isUploadingProfilePhoto = false }

        do {
            let uploadedURL = try await service.uploadProfileImage(imageData: imageData)
            let updated = await service.updateMyProfileImage(profileImageURL: uploadedURL)
            if updated {
                showProfilePhotoUpdatedToast()
            } else {
                profilePhotoErrorMessage = service.errorMessage ?? "프로필 사진 변경에 실패했어요."
            }
        } catch {
            profilePhotoErrorMessage = Self.profilePhotoErrorMessage(for: error)
        }
    }

    func save() async {
        guard isSaveEnabled else { return }
        guard let service else {
            saveErrorMessage = "프로필 저장을 준비하지 못했어요."
            return
        }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let success = await service.updateMyProfile(
            nickname: trimmedNickname
        )

        if success {
            originalNickname = trimmedNickname
            isEditSheetPresented = false
            return
        }

        saveErrorMessage = service.errorMessage ?? "프로필 수정에 실패했어요."
    }

    private func clearProfilePhotoToast() {
        profilePhotoToastMessage = nil
        profilePhotoToastDismissTask = nil
    }

    private static func profilePhotoErrorMessage(for error: Error) -> String {
        if let edgeError = error as? EdgeAPIError {
            if let errorId = edgeError.errorId, !errorId.isEmpty {
                return "프로필 사진 업로드 실패 (\(errorId)): \(edgeError.message)"
            }
            return "프로필 사진 업로드 실패: \(edgeError.message)"
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return "프로필 사진 업로드 실패: \(description)"
        }

        return "프로필 사진 업로드에 실패했어요. 잠시 후 다시 시도해 주세요."
    }
}
