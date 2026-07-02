import SwiftUI

/// Compact card shown in the Siri/Shortcuts confirmation dialog.
struct ProductConfirmationSnippet: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(product.priceFormatted)
                    .font(.title3.bold())
                    .foregroundStyle(.tint)
                Text(product.retailer.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    @ViewBuilder private var thumbnail: some View {
        if let url = product.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                placeholderIcon
            }
            .frame(width: 64, height: 64)
        } else {
            placeholderIcon.frame(width: 64, height: 64)
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary)
            .overlay(Image(systemName: "shippingbox.fill").foregroundStyle(.secondary))
    }
}
