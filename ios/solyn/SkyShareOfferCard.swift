//
//  SkyShareOfferCard.swift
//  solyn
//
//  The once-only offer at nights 7, 21 and 42 (see `SkyShareOffer`).
//

import SwiftUI

/// One pending offer: the night it is for and the card already rendered.
struct SkyOfferPrompt {
    let night: Int
    let image: UIImage
    let description: String
}

/// What goes to the system share sheet: the PNG and one line of text.
struct SkyShareItems: Identifiable {
    let url: URL
    let text: String
    var id: String { url.absoluteString }
}

/// A calm card on the Today screen: a small preview of the Story card, one
/// line, Share and Not now.
///
/// The preview IS the card that will be shared, rendered from the same call,
/// so what someone sees here is exactly what leaves the phone if they tap
/// Share — and nothing leaves if they do not. Flat, like the rest of the
/// app's chrome; the sky inside the preview keeps its own look.
struct SkyShareOfferCard: View {
    let night: Int
    let image: UIImage
    let imageDescription: String
    let onShare: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(imageDescription)

            VStack(alignment: .leading, spacing: 10) {
                Text(SkyShareOffer.headline(night))
                    .font(.dv(.headline))
                    .foregroundColor(theme.textColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text("A picture of your sky \u{2014} no words from your entries. Made on this phone; nothing is sent unless you pick somewhere to send it.", comment: "Today screen: explains the one-time offer to share a picture of the user's constellation.")
                    .font(.dv(.footnote))
                    .foregroundColor(theme.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: onShare) {
                        Text("Share", comment: "Button: share the picture of the sky through the system share sheet.")
                            .font(.dv(.subheadline, weight: .semibold))
                            .foregroundColor(theme.isNight ? DS.Palette.navy : .white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(theme.accentColor))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens the share sheet with a picture of your sky.", comment: "VoiceOver hint for the Share button on the sky share offer."))

                    Button(action: onDismiss) {
                        Text("Not now", comment: "Button: dismiss the one-time offer to share the sky. It is not offered again for this night.")
                            .font(.dv(.subheadline))
                            .foregroundColor(theme.secondaryTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(DS.Palette.gold.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
