//
//  BaseChipContainer.swift
//  NailClient
//

import SwiftUI

struct BaseChipContainer<Content: View>: View {
    let style: FeedChipPreset.Style
    let accessibilityLabel: String?
    let action: () -> Void
    private let content: () -> Content

    init(
        style: FeedChipPreset.Style,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.content = content
    }

    var body: some View {
        Group {
            if let accessibilityLabel {
                chipButton.accessibilityLabel(accessibilityLabel)
            } else {
                chipButton
            }
        }
    }

    private var chipButton: some View {
        Button(action: action) {
            content()
                .font(style.font)
                .foregroundStyle(style.foreground)
                .frame(minWidth: style.minWidth)
                .padding(.horizontal, style.horizontalPadding)
                .padding(.vertical, style.verticalPadding)
                .background(chipFillShape)
                .overlay(chipStrokeShape)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chipFillShape: some View {
        switch style.shape {
        case .capsule:
            Capsule(style: .continuous)
                .fill(style.background)
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.background)
        }
    }

    @ViewBuilder
    private var chipStrokeShape: some View {
        switch style.shape {
        case .capsule:
            Capsule(style: .continuous)
                .stroke(style.borderColor, lineWidth: style.borderWidth)
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(style.borderColor, lineWidth: style.borderWidth)
        }
    }
}
