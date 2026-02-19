import SwiftUI

struct FeedReservationOptionRowView: View {
    let option: FeedReservationOption
    @Binding var quantity: Int
    let unitPriceText: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .appTypography(size: 15, weight: .semibold)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)

                Text("1개당 \(unitPriceText)")
                    .appTypography(size: 12, weight: .medium)
                    .foregroundStyle(FeedDesignTokens.detailSecondaryText)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                quantityButton(systemName: "minus") {
                    quantity = max(0, quantity - 1)
                }
                .disabled(quantity <= 0)

                Text("\(quantity)")
                    .appTypography(size: 15, weight: .bold)
                    .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                    .frame(minWidth: 20)

                quantityButton(systemName: "plus") {
                    quantity = min(option.maxQuantity, quantity + 1)
                }
                .disabled(quantity >= option.maxQuantity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FeedDesignTokens.detailSubCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                )
        )
        .accessibilityIdentifier("reservation.sheet.option.row.\(option.id)")
    }

    private func quantityButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .appTypography(size: 12, weight: .bold)
                .foregroundStyle(FeedDesignTokens.detailPrimaryText)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(FeedDesignTokens.detailCardBackground)
                        .overlay(
                            Circle()
                                .stroke(FeedDesignTokens.detailBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FeedReservationOptionRowView(
        option: FeedReservationOption.defaultTemplates[0],
        quantity: .constant(1),
        unitPriceText: "₩5,000"
    )
    .padding()
    .background(FeedDesignTokens.detailBackground)
}
