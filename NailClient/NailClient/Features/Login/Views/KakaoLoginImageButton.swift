//
//  KakaoLoginImageButton.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI
import UIKit

struct KakaoLoginImageButton: View {
    let assetName: String
    let action: @Sendable () async -> Void

    @State private var isLoading = false

    var body: some View {
        Button {
            guard !isLoading else { return }
            isLoading = true
            Task {
                await action()
                isLoading = false
            }
        } label: {
            ZStack {
                if let uiImage = UIImage(named: assetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("카카오로 시작하기")
                } else {
                    // Asset이 아직 없을 때도 화면이 깨지지 않도록 fallback 제공
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 254/255, green: 229/255, blue: 0/255))
                        .overlay {
                            Text("카카오로 시작하기")
                                .font(.headline)
                                .foregroundStyle(.black)
                        }
                        .frame(height: 52)
                }

                if isLoading {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.black.opacity(0.08))
                        .overlay {
                            ProgressView()
                                .tint(.black)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 24) {
        KakaoLoginImageButton(assetName: "kakao_login_large_wide") {}
        KakaoLoginImageButton(assetName: "missing_asset_name") {}
    }
    .padding()
}
