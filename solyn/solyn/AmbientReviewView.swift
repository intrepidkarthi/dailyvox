import SwiftUI

// v1.5.5 — the review-and-discard sheet for ambient signals. Same promise as
// the Body Twin review: nothing here has touched your Twin. Keep folds a
// signal's derived label into your Twin as context for that day; Let go
// deletes it unseen. Mirrors BodyTwinReviewView's structure and copy.
struct AmbientReviewView: View {
    @ObservedObject private var queue = PendingAmbientSignalQueue.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if queue.items.isEmpty {
                    emptyState
                } else {
                    signalList
                }
            }
            .navigationTitle("Your day, for review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Nothing waiting")
                .font(.headline)
            Text("When DailyVox notices context from your day — the kind of photos you took, the music you reached for — it waits here for you to keep or let go.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var signalList: some View {
        List {
            Section {
                ForEach(queue.items) { item in
                    signalRow(item)
                }
            } header: {
                Text("These signals came from your day. Keep what feels true — your Twin learns nothing until you do. Let go, and it's deleted.")
                    .textCase(nil)
            }

            if queue.count >= 2 {
                Section {
                    Button {
                        keepAll()
                    } label: {
                        Text("Keep all \(queue.count)")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func signalRow(_ item: AmbientSignal) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.kind == .photo ? "photo.on.rectangle.angled" : "music.note")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                keep(item)
            } label: {
                Text("Keep")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                queue.remove(id: item.id)
            } label: {
                Label("Let go", systemImage: "trash")
            }
        }
    }

    private func keep(_ item: AmbientSignal) {
        guard let signal = queue.keep(id: item.id) else { return }
        AmbientSignalManager.shared.fold(signal)
    }

    private func keepAll() {
        let drained = queue.drainAll()
        AmbientSignalManager.shared.fold(contentsOf: drained)
    }
}
