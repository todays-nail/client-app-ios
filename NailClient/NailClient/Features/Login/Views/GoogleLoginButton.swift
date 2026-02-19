//
//  GoogleLoginButton.swift
//  NailClient
//

import SwiftUI

struct GoogleLoginButton: View {
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }

                HStack(spacing: 10) {
                    Text("G")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x4285F4))
                    Text("Google로 시작하기")
                        .appTypography(size: 16, weight: .semibold)
                        .foregroundStyle(Color(hex: 0x1F1F1F))
                }
                .padding(.horizontal, 16)

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
    GoogleLoginButton {}
        .frame(height: 58)
        .padding()
}
