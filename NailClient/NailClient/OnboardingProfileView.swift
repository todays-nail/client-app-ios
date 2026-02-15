//
//  OnboardingProfileView.swift
//  NailClient
//
//  Created by 김대환 on 2/15/26.
//

import SwiftUI

struct OnboardingProfileView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var nickname = ""
    @State private var phone = ""
    @State private var isSubmitting = false

    @State private var showPhotoNotReadyAlert = false
    @State private var showMaxStyleAlert = false

    @FocusState private var focusedField: Field?

    @State private var selectedStyles: Set<PreferredStyle> = []

    private enum Field: Hashable {
        case nickname
        case phone
    }

    private enum PreferredStyle: String, CaseIterable, Identifiable {
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

    var isSubmitEnabled: Bool {
        !isSubmitting && !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    ZStack {
                        Color(.systemBackground)

                        ScrollView {
                            VStack(spacing: 0) {
                                profileSection

                                inputSection
                                    .padding(.top, 8)

                                styleSection
                                    .padding(.top, 24)
                                    .padding(.bottom, 24)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            topBar
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            bottomCTA
                        }
                    }
                    .frame(maxWidth: 420)
                    .frame(maxHeight: .infinity)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                        radius: 16,
                        x: 0,
                        y: 2
                    )

                    Spacer(minLength: 0)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedField = nil }
                }
            }
            .alert(
                "오류",
                isPresented: Binding(
                    get: { appModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { appModel.errorMessage = nil }
                    }
                )
            ) {
                Button("확인", role: .cancel) { appModel.errorMessage = nil }
            } message: {
                Text(appModel.errorMessage ?? "")
            }
            .alert("준비 중", isPresented: $showPhotoNotReadyAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("프로필 사진 추가 기능은 다음 단계에서 제공될 예정이에요.")
            }
            .alert("최대 3개까지 선택", isPresented: $showMaxStyleAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("선호하는 스타일은 최대 3개까지 선택할 수 있어요.")
            }
        }
    }

    private var primary: Color { LoginDesignTokens.primaryHTML }
    private var backgroundColor: Color {
        colorScheme == .dark ? LoginDesignTokens.backgroundDarkHTML : LoginDesignTokens.backgroundLightHTML
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    Task { await appModel.signOut() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Text("프로필 설정")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(colorScheme == .dark ? Color.white : Color(.label))
                .padding(.horizontal, 24)

            Text("간단한 정보만 입력하면 바로 시작할 수 있어요")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color(.secondaryLabel))
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 16)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    (colorScheme == .dark ? Color.black : Color.white)
                        .opacity(0.20)
                }
        }
    }

    private var profileSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(colorScheme == .dark ? primary.opacity(0.10) : Color(.systemGray6))
                    .overlay {
                        Circle()
                            .stroke(colorScheme == .dark ? primary.opacity(0.20) : Color(.systemGray5), lineWidth: 1)
                    }
                    .frame(width: 112, height: 112)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .opacity(0.55)
                    }
                    .accessibilityLabel("프로필 사진")

                Button {
                    showPhotoNotReadyAlert = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(primary, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(colorScheme == .dark ? Color(.systemBackground) : Color.white, lineWidth: 2)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("사진 추가")
            }

            Text("사진 추가")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 26)
    }

    private var inputSection: some View {
        VStack(spacing: 18) {
            labeledTextField(
                label: "닉네임",
                placeholder: "닉네임을 입력해주세요",
                text: $nickname,
                field: .nickname,
                keyboardType: .default,
                textContentType: .nickname
            )

            labeledTextField(
                label: "휴대폰 번호",
                placeholder: "010-0000-0000",
                text: $phone,
                field: .phone,
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("선호하는 스타일")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color(.label))
                    .textCase(.uppercase)

                Spacer()

                Text("최대 3개")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primary)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 12)

            FlowLayout(spacing: 8) {
                ForEach(PreferredStyle.allCases) { style in
                    let isSelected = selectedStyles.contains(style)
                    Button {
                        toggleStyle(style)
                    } label: {
                        Text(style.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? Color.white : (colorScheme == .dark ? Color.white.opacity(0.75) : Color(.secondaryLabel)))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(
                                        isSelected
                                            ? primary
                                            : (colorScheme == .dark ? primary.opacity(0.10) : Color(.systemGray6))
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: (colorScheme == .dark ? LoginDesignTokens.backgroundDarkHTML : Color.white).opacity(0.0), location: 0.0),
                    .init(color: (colorScheme == .dark ? LoginDesignTokens.backgroundDarkHTML : Color.white).opacity(0.75), location: 0.35),
                    .init(color: (colorScheme == .dark ? LoginDesignTokens.backgroundDarkHTML : Color.white).opacity(1.0), location: 1.0),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 76)
            .allowsHitTesting(false)
            .overlay(alignment: .bottom) {
                Button {
                    submit()
                } label: {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("시작하기")
                            .font(.system(size: 18, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(PressScaleButtonStyle())
                .foregroundStyle(.white)
                .background(primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: primary.opacity(0.30), radius: 22, x: 0, y: 10)
                .disabled(!isSubmitEnabled)
                .opacity(isSubmitEnabled ? 1.0 : 0.55)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }

    private func submit() {
        guard isSubmitEnabled else { return }
        focusedField = nil

        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneTrimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        isSubmitting = true
        Task {
            await appModel.completeOnboarding(
                nickname: trimmed,
                phone: phoneTrimmed.isEmpty ? nil : phoneTrimmed,
                profileImageURL: nil
            )
            isSubmitting = false
        }
    }

    private func toggleStyle(_ style: PreferredStyle) {
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

    @ViewBuilder
    private func labeledTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color(.tertiaryLabel))
                .tracking(0.8)
                .padding(.leading, 4)

            TextField(
                "",
                text: text,
                prompt: Text(placeholder)
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.25) : Color(.tertiaryLabel))
            )
            .textInputAutocapitalization(.never)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(inputBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(inputBorder(for: field), lineWidth: focusedField == field ? 2 : 1)
            }
            .shadow(color: focusShadow(for: field), radius: 10, x: 0, y: 4)
            .foregroundStyle(colorScheme == .dark ? Color.white : Color(.label))
            .font(.system(size: 15, weight: .medium))
        }
    }

    private var inputBackground: Color {
        colorScheme == .dark ? primary.opacity(0.06) : Color(.systemGray6)
    }

    private func inputBorder(for field: Field) -> Color {
        if focusedField == field {
            return primary
        }
        return colorScheme == .dark ? primary.opacity(0.20) : Color(.systemGray5)
    }

    private func focusShadow(for field: Field) -> Color {
        guard focusedField == field else { return .clear }
        return primary.opacity(colorScheme == .dark ? 0.28 : 0.18)
    }
}

#Preview {
    OnboardingProfileView()
        .environmentObject(AppModel())
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                measuredWidth = max(measuredWidth, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        measuredWidth = max(measuredWidth, x > 0 ? x - spacing : 0)
        return CGSize(width: proposal.width ?? measuredWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
