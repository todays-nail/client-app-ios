//
//  AINailGenerationView.swift
//  NailClient
//

import PhotosUI
import SwiftUI
import UIKit

struct AINailGenerationView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = AINailGenerationViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("네일 쉐입", selection: $viewModel.selectedShape) {
                    ForEach(AINailShape.allCases) { shape in
                        Text(shape.title).tag(shape)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text("추가 요청사항")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $viewModel.userPrompt)
                        .frame(minHeight: 88)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    Text("예: 봄 느낌 파스텔, 작은 꽃 포인트, 과하지 않게")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                photoSelectionSection(
                    title: "손 사진",
                    selection: $viewModel.selectedHandPhotoItem,
                    image: viewModel.handPreviewImage
                )

                photoSelectionSection(
                    title: "네일 레퍼런스",
                    selection: $viewModel.selectedReferencePhotoItem,
                    image: viewModel.referencePreviewImage
                )

                Button {
                    Task { await viewModel.submitGeneration() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                        Text(viewModel.isSubmitting ? "생성 중..." : "AI 네일 생성하기")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.canSubmit ? Color.accentColor : Color.gray.opacity(0.45))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.canSubmit)

                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let resultImageURL = viewModel.resultImageURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("생성 결과")
                            .font(.headline)
                        AsyncImage(url: resultImageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 220)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                Text("결과 이미지를 불러오지 못했습니다.")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("AI 네일 생성")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.bind(service: appViewModel)
        }
        .onChange(of: viewModel.selectedHandPhotoItem) { _ in
            Task { await viewModel.loadHandPhoto() }
        }
        .onChange(of: viewModel.selectedReferencePhotoItem) { _ in
            Task { await viewModel.loadReferencePhoto() }
        }
    }

    @ViewBuilder
    private func photoSelectionSection(
        title: String,
        selection: Binding<PhotosPickerItem?>,
        image: UIImage?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            PhotosPicker(selection: selection, matching: .images) {
                Label("사진 선택", systemImage: "photo")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    NavigationStack {
        AINailGenerationView()
            .environmentObject(AppViewModel())
    }
}
