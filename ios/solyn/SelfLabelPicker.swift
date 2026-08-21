//
//  SelfLabelPicker.swift
//  solyn
//
//  Research-pilot self-label capture: an optional one-tap "How did that feel?"
//  picker shown right after a recording is saved (pilot participants only —
//  gated by the "pilotLabelingEnabled" setting in Settings → Research).
//
//  The label is stored in the dedicated selfLabelEmotion/selfLabelIntensity
//  attributes and deliberately NEVER touches the `mood` field or the Twin
//  engine (`processEntry`/`TwinEntryInput`) — the manual mood chain feeds
//  emotionalSignature.emotionFrequency, and research labels must not
//  contaminate the Twin's automatic model of the user. Labels leave the
//  device only through the user-initiated research export in Settings.
//
//  Taxonomy: the research 7-class canon (6 emotions + neutral), a strict
//  subset of the engine's DetectedEmotion rawValues so exports stay
//  corpus-compatible.
//

import SwiftUI
import CoreData

/// The 7-class self-report canon (anger, disgust, fear, joy, neutral,
/// sadness, surprise). Raw values match `DetectedEmotion` in the engine.
enum SelfLabelEmotion: String, CaseIterable, Identifiable {
    case joy = "joy"
    case sadness = "sadness"
    case anger = "anger"
    case fear = "fear"
    case surprise = "surprise"
    case disgust = "disgust"
    case neutral = "neutral"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .joy: return "Joy"
        case .sadness: return "Sadness"
        case .anger: return "Anger"
        case .fear: return "Fear"
        case .surprise: return "Surprise"
        case .disgust: return "Disgust"
        case .neutral: return "Neutral"
        }
    }

    /// SF Symbols matching DetectedEmotion.emoji so the vocabulary reads
    /// the same wherever emotions appear in the app.
    var icon: String {
        switch self {
        case .joy: return "sun.max.fill"
        case .sadness: return "cloud.rain.fill"
        case .anger: return "flame.fill"
        case .fear: return "wind"
        case .surprise: return "sparkles"
        case .disgust: return "xmark.circle.fill"
        case .neutral: return "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .joy: return .yellow
        case .sadness: return .blue
        case .anger: return .red
        case .fear: return .indigo
        case .surprise: return .orange
        case .disgust: return .brown
        case .neutral: return .secondary
        }
    }
}

/// Compact post-recording picker card. One tap on an emotion saves
/// (emotion + currently selected intensity) onto the entry and dismisses;
/// Skip stores nothing. Latest-wins when the day already has a label.
struct SelfLabelPickerCard: View {
    @Environment(\.managedObjectContext) private var viewContext

    let entry: DiaryEntry
    let onDone: () -> Void

    @State private var intensity: Int = 2

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]

    var body: some View {
        VStack(spacing: 14) {
            Text("How did that feel?")
                .font(.dv(.title3, design: .rounded, weight: .bold))

            Text("One tap — this stays on your phone and helps the research pilot.")
                .font(.dv(.footnote))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(SelfLabelEmotion.allCases) { emotion in
                    Button {
                        save(emotion)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: emotion.icon)
                                .font(.dv(.title3))
                                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                .foregroundColor(emotion.color)
                            Text(emotion.displayName)
                                .font(.dv(.caption2, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(emotion.displayName), intensity \(intensity)")
                }
            }

            // Intensity 1–3, applied to whichever emotion is tapped next.
            HStack(spacing: 14) {
                Text("How strongly?")
                    .font(.dv(.caption))
                    .foregroundColor(.secondary)
                ForEach(1...3, id: \.self) { level in
                    Button {
                        intensity = level
                    } label: {
                        Circle()
                            .fill(level <= intensity ? DS.Palette.gold : Color(.tertiarySystemFill))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Intensity \(level)")
                }
            }

            Button("Skip") {
                onDone()
            }
            .font(.dv(.subheadline, weight: .medium))
            .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: 340)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }

    private func save(_ emotion: SelfLabelEmotion) {
        // KVC (house pattern, cf. EntryDetailView.saveMood) — NOT the `mood`
        // field; see header note on contamination.
        entry.setValue(emotion.rawValue, forKey: "selfLabelEmotion")
        entry.setValue(Int16(intensity), forKey: "selfLabelIntensity")
        entry.setValue(Date(), forKey: "updatedAt")
        do {
            try viewContext.save()
            HapticManager.shared.moodSelected()
        } catch {
            // Never block or fail the recording flow over a label.
        }
        onDone()
    }
}
