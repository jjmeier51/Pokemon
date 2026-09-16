import SwiftUI
import UIKit

/// Renders a card scan from the image store, with a placeholder while decoding.
struct CardImageView: View {
    let card: Card
    var full = false
    var maxPixelSize: CGFloat = 480
    var cornerRadius: CGFloat = 10

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .aspectRatio(0.716, contentMode: .fit)
                    .overlay {
                        PokeballWatermark()
                            .foregroundStyle(Color.white.opacity(0.08))
                            .padding(24)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: card.id + (full ? "-full" : "-thumb")) {
            image = full ? await ImageStore.shared.fullImage(for: card) : await ImageStore.shared.thumbnail(for: card, maxPixelSize: maxPixelSize)
        }
    }
}
