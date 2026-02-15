//
//  OnboardingProfileViewModel.swift
//  NailClient
//

import Foundation
import Combine
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class OnboardingProfileViewModel: ObservableObject {
    enum PreferredStyle: String, CaseIterable, Identifiable {
        case officeMinimal = "오피스/미니멀"
        case natural = "청순/내추럴"
        case lovelyCute = "러블리/귀여움"
        case hipStreet = "힙/스트릿"
        case chicModern = "시크/모던"
        case kitschUnique = "키치/유니크"
        case glitterPearl = "글리터/펄"
        case french = "프렌치"
        case gradationOmbre = "그라데이션/옴브레"
        case wedding = "웨딩"
        case seasonHoliday = "시즌/홀리데이"
        case pointArt = "포인트아트"

        var id: String { rawValue }
    }

    @Published var nickname: String = ""
    @Published var phone: String = ""
    @Published var isSubmitting: Bool = false

    @Published var selectedStyles: Set<PreferredStyle> = []
    @Published var showMaxStyleAlert: Bool = false

    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var profileUIImage: UIImage?
    @Published var isLoadingPhoto: Bool = false
    @Published var photoLoadErrorMessage: String?
    @Published var showPhotoLoadErrorAlert: Bool = false

    var isSubmitEnabled: Bool {
        !isSubmitting && !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toggleStyle(_ style: PreferredStyle) {
        if selectedStyles.contains(style) {
            selectedStyles.remove(style)
            return
        }

        guard selectedStyles.count < 3 else {
            showMaxStyleAlert = true
            return
        }

        selectedStyles.insert(style)
    }

    func submit(appViewModel: AppViewModel) async {
        guard isSubmitEnabled else { return }

        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneTrimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        isSubmitting = true
        defer { isSubmitting = false }

        await appViewModel.completeOnboarding(
            nickname: trimmed,
            phone: phoneTrimmed.isEmpty ? nil : phoneTrimmed,
            profileImageURL: nil
        )
    }

    func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoLoadError.emptyData
            }
            guard let uiImage = UIImage(data: data) else {
                throw PhotoLoadError.invalidImageData
            }
            profileUIImage = uiImage
        } catch {
            photoLoadErrorMessage = error.localizedDescription
            showPhotoLoadErrorAlert = true
        }
    }
}

private enum PhotoLoadError: LocalizedError {
    case emptyData
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "선택한 사진을 불러오지 못했어요."
        case .invalidImageData:
            return "사진 데이터가 올바르지 않아요."
        }
    }
}
