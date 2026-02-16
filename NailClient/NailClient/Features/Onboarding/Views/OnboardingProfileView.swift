//
//  OnboardingProfileView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

/// Onboarding flow container:
/// - Step 1: photo + nickname + phone
/// - Step 2: preferred styles + submit
struct OnboardingProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @StateObject private var viewModel = OnboardingProfileViewModel()
    @State private var showStyleStep: Bool = false

    var body: some View {
        NavigationStack {
            OnboardingProfileBasicsStepView(viewModel: viewModel) {
                showStyleStep = true
            }
            .navigationDestination(isPresented: $showStyleStep) {
                OnboardingProfileStyleStepView(viewModel: viewModel)
            }
        }
        .alert(
            "오류",
            isPresented: Binding(
                get: { appViewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { appViewModel.errorMessage = nil }
                }
            )
        ) {
            Button("확인", role: .cancel) { appViewModel.errorMessage = nil }
        } message: {
            Text(appViewModel.errorMessage ?? "")
        }
        .alert("사진 불러오기 실패", isPresented: $viewModel.showPhotoLoadErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.photoLoadErrorMessage ?? "알 수 없는 오류가 발생했어요.")
        }
        .alert("최대 3개까지 선택", isPresented: $viewModel.showMaxStyleAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("선호하는 스타일은 최대 3개까지 선택할 수 있어요.")
        }
    }
}

#Preview {
    OnboardingProfileView()
        .environmentObject(AppViewModel())
}

