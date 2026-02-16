//
//  ReservationSegmentControl.swift
//  NailClient
//

import SwiftUI

struct ReservationSegmentControl: View {
    @Binding var selectedSegment: ReservationSegment

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReservationSegment.allCases) { segment in
                Button {
                    selectedSegment = segment
                } label: {
                    Text(segment.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedSegment == segment ? Color.white : ReservationDesignTokens.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: ReservationDesignTokens.segmentHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedSegment == segment ? ReservationDesignTokens.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(segment.title)
                .accessibilityIdentifier("reservation.segment.\(segment.rawValue)")
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ReservationDesignTokens.mutedButtonBackground)
        )
    }
}

#Preview {
    ReservationSegmentControl(selectedSegment: .constant(.upcoming))
        .padding()
}
