//
//  ShareSheetView.swift
//  solyn
//
//  Card preview → OS share sheet (design §F, "share flow").
//

import SwiftUI
import CoreData

/// The card is rendered on this device and handed to the system share sheet.
/// The app never sends it anywhere — with no networking code in the target it
/// could not, which is exactly the claim the cards are making.
///
/// NAMES ARE OFF BY DEFAULT. The toggle exists because some people do want to
/// post "Sarah · 61 nights", but the default has to be the safe one: a shared
/// card is irreversible the moment it leaves, and the person named never got
/// a say.
struct ShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var theme = ThemeManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    @State private var card: Shareables.Card = .mySky
    @State private var includeNames = false
    @State private var airplaneDeclared = false
    @State private var shareURL: URL?

    private var facts: [Shareables.Fact] { Shareables.facts(from: Array(entries)) }

    /// The milestone card is only offered once it exists. A locked "night 42"
    /// chip shown to someone on night 9 turns a reward into a nag, which is the
    /// gamification guilt the design explicitly rules out.
    private var cards: [Shareables.Card] {
        Shareables.Card.allCases.filter {
            $0 != .milestone || Shareables.milestoneReached(facts) != nil
        }
    }

    private var image: UIImage {
        Shareables.render(card, facts: facts,
                          includeNames: includeNames, airplane: airplaneDeclared)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Rendered on this phone and handed to whatever you pick. DailyVox has no way to send it itself.")
                        .font(.dsCaption)
                        .foregroundColor(theme.secondaryTextColor)

                    picker

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // The portrait card is sized by HEIGHT and lets width
                        // follow; constraining width first and then applying a
                        // 9:16 ratio makes the ratio win and draws a preview
                        // taller than the sheet, over its own buttons.
                        .frame(maxWidth: card == .wallpaper ? 260 : .infinity)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text(card.caption)
                        .font(.dsCaption)
                        .foregroundColor(theme.secondaryTextColor)

                    if card == .yearOne { namesToggle }
                    if card == .mySky { airplaneToggle }

                    actions
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $shareURL) { url in
                ActivityView(items: [url])
            }
        }
    }

    private var picker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(cards) { c in
                let active = c == card
                Text(c.title)
                    .font(.system(size: 12, weight: active ? .heavy : .bold, design: .rounded))
                    .foregroundColor(active
                                     ? (theme.isNight ? DS.Palette.navy : .white)
                                     : theme.secondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(active ? theme.accentColor : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(active ? .clear : theme.secondaryTextColor.opacity(0.25),
                                    lineWidth: 1.5)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { card = c }
            }
        }
    }

    private var namesToggle: some View {
        Toggle(isOn: $includeNames) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Include names").font(.dsCallout).foregroundColor(theme.textColor)
                Text(includeNames ? "The card will name a real person."
                                  : "Off — the card says \u{201C}someone\u{201D}.")
                    .font(.dsCaption2)
                    .foregroundColor(includeNames ? theme.goldText : theme.secondaryTextColor)
            }
        }
        .tint(theme.accentColor)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(theme.cardBackgroundColor))
    }

    /// User-declared, not detected. iOS gives no public way to read airplane
    /// mode, and a stamp the app cannot verify has to be the user's claim
    /// rather than the app's — the whole format depends on the stamp being
    /// true, so quietly asserting it would poison exactly the thing it sells.
    private var airplaneToggle: some View {
        Toggle(isOn: $airplaneDeclared) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stamp \u{201C}on airplane mode\u{201D}")
                    .font(.dsCallout).foregroundColor(theme.textColor)
                Text("Only if it is actually on — iOS will not let the app check for you.")
                    .font(.dsCaption2).foregroundColor(theme.secondaryTextColor)
            }
        }
        .tint(theme.accentColor)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(theme.cardBackgroundColor))
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if card == .wallpaper {
                Text("Save to Photos, then set it from there — iOS has no way to hand a wallpaper straight to the lock screen.")
                    .font(.dsCaption2)
                    .foregroundColor(theme.secondaryTextColor)
            }
            Button {
                if let url = Shareables.pngURL(card, image: image) { shareURL = url }
            } label: {
                Text(card == .wallpaper ? "Save or share the image" : "Share")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.isNight ? DS.Palette.navy : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 20).fill(theme.accentColor))
            }
            .buttonStyle(.plain)
        }
    }
}

/// URL is Identifiable so it can drive `.sheet(item:)` directly.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
