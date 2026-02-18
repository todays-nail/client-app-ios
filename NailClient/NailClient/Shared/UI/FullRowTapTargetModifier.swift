//
//  FullRowTapTargetModifier.swift
//  NailClient
//

import SwiftUI

private struct FullRowTapTargetModifier: ViewModifier {
    let minHeight: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .contentShape(Rectangle())
    }
}

extension View {
    func fullRowTapTarget(minHeight: CGFloat = 44, alignment: Alignment = .leading) -> some View {
        modifier(
            FullRowTapTargetModifier(
                minHeight: minHeight,
                alignment: alignment
            )
        )
    }
}
