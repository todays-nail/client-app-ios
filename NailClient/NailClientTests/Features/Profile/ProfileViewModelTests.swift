//
//  ProfileViewModelTests.swift
//  NailClientTests
//

import Foundation
import Testing
@testable import NailClient

@MainActor
struct ProfileViewModelTests {
    @Test
    func 닉네임_유효성검증을수행한다() {
        let viewModel = ProfileViewModel()

        viewModel.nickname = ""
        #expect(viewModel.nicknameValidationMessage != nil)

        viewModel.nickname = "a"
        #expect(viewModel.nicknameValidationMessage != nil)

        viewModel.nickname = "valid_user"
        #expect(viewModel.nicknameValidationMessage == nil)
    }

    @Test
    func 동일값이면_저장버튼이비활성화된다() {
        let user = AppUser.preview(nickname: "tester")
        let viewModel = ProfileViewModel()

        viewModel.sync(from: user)

        #expect(viewModel.hasChanges == false)
        #expect(viewModel.isSaveEnabled == false)
    }

    @Test
    func showComingSoon_신규케이스를정상설정한다() {
        let viewModel = ProfileViewModel()

        viewModel.showComingSoon(.likedDesigns)
        #expect(viewModel.comingSoonItem == .likedDesigns)

        viewModel.showComingSoon(.settings)
        #expect(viewModel.comingSoonItem == .settings)
    }

    @Test
    func makeHeaderDisplay_닉네임없으면_기본문구를반환한다() {
        let viewModel = ProfileViewModel()
        let user = AppUser.preview(nickname: nil)

        let display = viewModel.makeHeaderDisplay(from: user)

        #expect(display.name == "닉네임 미설정")
    }

    @Test
    func makeHeaderDisplay_프로필URL이비었거나잘못되면_nil을반환한다() {
        let viewModel = ProfileViewModel()
        let emptyURLUser = AppUser.preview(nickname: "tester", profileImageURL: " ")
        let invalidURLUser = AppUser.preview(nickname: "tester", profileImageURL: "https://exam ple.com")

        let emptyURLDisplay = viewModel.makeHeaderDisplay(from: emptyURLUser)
        let invalidURLDisplay = viewModel.makeHeaderDisplay(from: invalidURLUser)

        #expect(emptyURLDisplay.profileImageURL == nil)
        #expect(invalidURLDisplay.profileImageURL == nil)
    }

    @Test
    func makeHeaderDisplay_정상값이면_trim후반영한다() {
        let viewModel = ProfileViewModel()
        let user = AppUser.preview(
            nickname: "  네일매니아  ",
            profileImageURL: " https://example.com/profile.png "
        )

        let display = viewModel.makeHeaderDisplay(from: user)

        #expect(display.name == "네일매니아")
        #expect(display.profileImageURL?.absoluteString == "https://example.com/profile.png")
    }

    @Test
    func showProfilePhotoUpdatedToast_호출시_메시지를즉시설정한다() {
        let viewModel = ProfileViewModel(profilePhotoToastDuration: .seconds(1))

        viewModel.showProfilePhotoUpdatedToast()

        #expect(viewModel.profilePhotoToastMessage == "프로필 사진이 변경되었어요.")
    }

    @Test
    func showProfilePhotoUpdatedToast_지속시간후_자동으로사라진다() async {
        let viewModel = ProfileViewModel(profilePhotoToastDuration: .milliseconds(30))

        viewModel.showProfilePhotoUpdatedToast()
        #expect(viewModel.profilePhotoToastMessage == "프로필 사진이 변경되었어요.")

        for _ in 0..<40 {
            if viewModel.profilePhotoToastMessage == nil {
                break
            }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(viewModel.profilePhotoToastMessage == nil)
    }

    @Test
    func dismissProfilePhotoUpdatedToast_호출시_즉시사라진다() {
        let viewModel = ProfileViewModel(profilePhotoToastDuration: .seconds(1))

        viewModel.showProfilePhotoUpdatedToast()
        viewModel.dismissProfilePhotoUpdatedToast()

        #expect(viewModel.profilePhotoToastMessage == nil)
    }

    @Test
    func save_성공시_시트를닫고에러를초기화한다() async {
        let currentUser = AppUser.preview(nickname: "before")
        let service = ProfileServiceSpy(updateMyProfileResult: true)
        let viewModel = ProfileViewModel()
        viewModel.beginEdit(from: currentUser)
        viewModel.nickname = "after"
        viewModel.bind(service: service)

        await viewModel.save()

        #expect(viewModel.isSaving == false)
        #expect(viewModel.isEditSheetPresented == false)
        #expect(viewModel.saveErrorMessage == nil)
        #expect(service.updateMyProfileCallCount == 1)
        #expect(service.capturedNicknames == ["after"])
    }

    @Test
    func save_실패시_시트를유지하고에러메시지를보여준다() async {
        let currentUser = AppUser.preview(nickname: "before")
        let service = ProfileServiceSpy(
            updateMyProfileResult: false,
            errorMessage: "프로필 수정 실패"
        )
        let viewModel = ProfileViewModel()
        viewModel.beginEdit(from: currentUser)
        viewModel.nickname = "after"
        viewModel.bind(service: service)

        await viewModel.save()

        #expect(viewModel.isSaving == false)
        #expect(viewModel.isEditSheetPresented == true)
        #expect(viewModel.saveErrorMessage == "프로필 수정 실패")
        #expect(service.updateMyProfileCallCount == 1)
        #expect(service.capturedNicknames == ["after"])
    }
}
