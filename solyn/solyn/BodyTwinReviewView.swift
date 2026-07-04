//
//  BodyTwinReviewView.swift
//  solyn
//
//  Review before your Twin learns: each pending snapshot is shown exactly as
//  captured, and nothing reaches the Twin until you tap Keep. Let go deletes
//  the snapshot unseen.
//

import SwiftUI
import DailyVoxTwinEngine

struct BodyTwinReviewView: View {
    @ObservedObject private var queue = PendingSnapshotQueue.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if queue.items.isEmpty {
                    emptyState
                } else {
                    reviewList
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Your body had a say")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Pending list

    private var reviewList: some View {
        VStack(spacing: 18) {
            Text("These signals arrived with your recent entries. Keep what feels true — your Twin learns nothing until you do. Let go, and it's deleted.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.top, 8)

            ForEach(queue.items) { item in
                snapshotRow(item)
                    .padding(.horizontal, 16)
            }

            if queue.count >= 2 {
                Button {
                    keepAll()
                } label: {
                    Text("Keep all \(queue.count)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [DS.Palette.sage, DS.Palette.sage.opacity(0.85)],
                                                   startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .padding(.bottom, 24)
    }

    private func snapshotRow(_ item: PendingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                contextTag(item.snapshot.activityContext)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(signals(in: item.snapshot), id: \.text) { signal in
                    HStack(spacing: 8) {
                        Image(systemName: signal.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(signal.color)
                            .frame(width: 18)
                        Text(signal.text)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        BodyTwinManager.shared.discardSnapshot(id: item.id)
                    }
                } label: {
                    Text("Let go")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Palette.coral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(DS.Palette.coral.opacity(0.12)))
                }
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        BodyTwinManager.shared.keepSnapshot(id: item.id)
                    }
                    HapticManager.shared.entrySaved()
                } label: {
                    Text("Keep")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(DS.Palette.sage))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundColor(DS.Palette.gold)
            Text("Nothing waiting")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text("When your body has something to add after an entry, it will rest here until you decide.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
    }

    // MARK: Rendering helpers

    /// The activity tag, rendered honestly — it tells you how to read the
    /// other numbers, never more than that.
    private func contextTag(_ context: ActivityContext) -> some View {
        let (label, tint): (String, Color) = {
            switch context {
            case .atRest:      return ("At rest", DS.Palette.sage)
            case .active:      return ("In motion", DS.Palette.terracotta)
            case .postWorkout: return ("Just after a workout", DS.Palette.gold)
            case .unknown:     return ("Context unknown", DS.Palette.inkMute)
            }
        }()
        return DSTag(text: label, tint: tint)
    }

    private func signals(in snapshot: HealthSnapshot) -> [(icon: String, color: Color, text: String)] {
        var rows: [(icon: String, color: Color, text: String)] = []
        if let sleep = snapshot.sleepHours {
            rows.append(("moon.zzz.fill", DS.Palette.sage,
                         String(format: "%.1f h sleep", sleep)))
        }
        if let hrv = snapshot.morningHRVMs {
            rows.append(("waveform.path.ecg", DS.Palette.terracotta,
                         "\(Int(hrv.rounded())) ms morning HRV"))
        }
        if let restingHR = snapshot.restingHRBpm {
            rows.append(("heart.fill", DS.Palette.coral,
                         "\(Int(restingHR.rounded())) bpm resting heart"))
        }
        if let steps = snapshot.stepsToday {
            rows.append(("figure.walk", DS.Palette.gold,
                         "\(steps.formatted()) steps"))
        }
        if let mindful = snapshot.mindfulMinutesToday {
            rows.append(("leaf.fill", DS.Palette.forest,
                         "\(mindful) mindful min"))
        }
        return rows
    }

    private func keepAll() {
        withAnimation(.spring(response: 0.4)) {
            for item in queue.items {
                BodyTwinManager.shared.keepSnapshot(id: item.id)
            }
        }
        HapticManager.shared.entrySaved()
    }
}
