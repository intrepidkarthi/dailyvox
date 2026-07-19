//
//  TwinChatView.swift
//  solyn
//
//  Ask Your Twin — a conversational interface to explore your journal data.
//
//  v1.7: on Apple-Intelligence devices (iOS 26+) answers come from the
//  on-device Foundation Models Twin — free-text questions, grounded in
//  retrieved journal entries, every answer citing the entries it drew from,
//  audited before render (engine `FoundationTwinChat`). Everywhere else, and
//  whenever the brain declines a turn, the classic template chat answers via
//  the engine's eval-locked `TwinResponseGenerator`. Zero network calls on
//  either path.
//
//  The in-tree template copy was deleted in v1.7 — `TwinQuestion` and
//  `TwinResponseGenerator` now resolve to the engine's injectable,
//  eval-tested definitions (DailyVoxTwinEngine/TwinChat.swift).
//

import SwiftUI
import CoreData
import DailyVoxTwinEngine
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Chat Message

struct TwinChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
    /// Journal entries this answer cited ("From your journal" chips).
    var citations: [TwinChatEvidence] = []
}

// MARK: - Twin Chat View

struct TwinChatView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var brain = TwinBrainManager.shared
    @Environment(\.managedObjectContext) private var viewContext

    @State private var messages: [TwinChatMessage] = []
    @State private var askedQuestions: Set<TwinQuestion> = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var latestFollowUps: [String] = []
    @State private var pipeline: Any?
    @State private var citationEntry: DiaryEntry?
    private let evidenceAdapter = TwinChatEvidenceAdapter()

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Welcome message
                        if messages.isEmpty {
                            welcomeCard
                                .padding(.top, 20)
                        }

                        ForEach(messages) { message in
                            chatBubble(for: message)
                        }

                        if isThinking {
                            thinkingBubble
                        }

                        // Invisible anchor for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: isThinking) { _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            Divider()
                .background(themeManager.secondaryTextColor.opacity(0.3))

            // Free-text input on EVERY device: the Foundation-Models brain
            // answers where available; everywhere else questions run through
            // semantic retrieval ("closest entries from your journal").
            inputBar
            if brain.status == .modelNotReady || brain.status == .appleIntelligenceOff {
                classicModeCaption
            }

            // Suggested questions chips
            questionChips
        }
        .navigationTitle("Ask Your Twin")
        .background(themeManager.backgroundColor.ignoresSafeArea())
        .task {
            // The chat's grounding depends on index freshness — the save path
            // in TodayView doesn't index, so catch up here (idempotent).
            SemanticSearchManager.shared.indexAll(from: viewContext)
            if pipeline == nil {
                pipeline = brain.makePipeline()
            }
        }
        .sheet(item: $citationEntry) { entry in
            NavigationView {
                EntryDetailView(entry: entry)
            }
            .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Welcome Card

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            // Small twin orb
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.accentColor.opacity(0.6),
                                themeManager.accentColor.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }

            Text("Ask me anything about your journal")
                .font(.headline)
                .foregroundColor(themeManager.textColor)

            Text(brain.isActive
                 ? "Ask in your own words, or tap a question below. Answers come from your entries, on this device — and show which entries they drew from."
                 : "Ask in your own words and I'll surface the closest entries from your journal, or tap a question below. Everything stays on this iPhone.")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Chat Bubble

    private func chatBubble(for message: TwinChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                twinOrb
                    .padding(.top, 4)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(message.isUser ? .white : themeManager.textColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.isUser
                                  ? themeManager.accentColor
                                  : themeManager.cardBackgroundColor)
                    )

                if !message.citations.isEmpty {
                    citationRow(for: message.citations)
                }
            }

            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }

    private var twinOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            themeManager.accentColor.opacity(0.7),
                            themeManager.accentColor.opacity(0.3)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 14
                    )
                )
                .frame(width: 28, height: 28)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
    }

    private var thinkingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            twinOrb
                .padding(.top, 4)
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Thinking…")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(themeManager.cardBackgroundColor)
            )
            Spacer(minLength: 40)
        }
    }

    // MARK: - Citations

    private func citationRow(for citations: [TwinChatEvidence]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("From your journal")
                .font(.caption2)
                .foregroundColor(themeManager.secondaryTextColor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(citations) { citation in
                        Button {
                            citationEntry = entry(for: citation.entryId)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 9))
                                Text("\(citation.date, format: .dateTime.month(.abbreviated).day()) · \(Int(citation.score * 100))%")
                                    .font(.caption2)
                            }
                            .foregroundColor(themeManager.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(themeManager.accentColor.opacity(0.12))
                            )
                        }
                    }
                }
            }
        }
        .padding(.leading, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your twin anything…", text: $inputText, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(themeManager.cardBackgroundColor)
                )
                .onSubmit { sendFreeText() }

            Button {
                sendFreeText()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(canSend ? themeManager.accentColor : themeManager.secondaryTextColor.opacity(0.4))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(themeManager.backgroundColor)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    private var classicModeCaption: some View {
        Text(brain.status == .modelNotReady
             ? "Classic mode — Apple Intelligence is still preparing the on-device model."
             : "Classic mode — turn on Apple Intelligence in Settings for conversational answers.")
            .font(.caption2)
            .foregroundColor(themeManager.secondaryTextColor)
            .padding(.top, 6)
    }

    // MARK: - Question Chips

    private var questionChips: some View {
        VStack(spacing: 8) {
            if !brain.isActive && availableQuestions.isEmpty {
                Text("You've asked all the questions! Tap any to ask again.")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.top, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Model-suggested follow-ups lead the row (FM path).
                    ForEach(latestFollowUps, id: \.self) { followUp in
                        Button {
                            send(text: followUp)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.system(size: 11))
                                Text(followUp)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundColor(themeManager.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(themeManager.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }

                    ForEach(displayedQuestions) { question in
                        Button {
                            askQuestion(question)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: question.icon)
                                    .font(.system(size: 11))
                                Text(question.rawValue)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundColor(askedQuestions.contains(question)
                                             ? themeManager.secondaryTextColor
                                             : themeManager.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(askedQuestions.contains(question)
                                          ? themeManager.cardBackgroundColor.opacity(0.6)
                                          : themeManager.accentColor.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        askedQuestions.contains(question)
                                        ? Color.clear
                                        : themeManager.accentColor.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
        }
        .background(themeManager.backgroundColor)
    }

    // MARK: - Logic

    private var availableQuestions: [TwinQuestion] {
        TwinQuestion.allCases.filter { !askedQuestions.contains($0) }
    }

    private var displayedQuestions: [TwinQuestion] {
        // Show unasked first, then asked ones
        let unasked = TwinQuestion.allCases.filter { !askedQuestions.contains($0) }
        let asked = TwinQuestion.allCases.filter { askedQuestions.contains($0) }
        return unasked + asked
    }

    private func askQuestion(_ question: TwinQuestion) {
        askedQuestions.insert(question)
        if brain.isActive {
            // Chips are one-tap prompt fillers on the FM path.
            send(text: question.rawValue)
        } else {
            // Classic path — the engine's eval-locked template surface.
            let userMessage = TwinChatMessage(text: question.rawValue, isUser: true)
            messages.append(userMessage)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let responseText = TwinResponseGenerator.generateResponse(
                    for: question,
                    twin: DigitalTwinEngine.shared,
                    profile: TwinChatProfile(from: LocalAIEngine.shared.userProfile))
                let twinMessage = TwinChatMessage(text: responseText, isUser: false)
                withAnimation(.easeIn(duration: 0.2)) {
                    messages.append(twinMessage)
                }
            }
        }
    }

    private func sendFreeText() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        send(text: trimmed)
    }

    /// The Foundation-Models path: grounded, cited, audited (engine-side).
    private func send(text: String) {
        guard !isThinking else { return }
        messages.append(TwinChatMessage(text: text, isUser: true))
        latestFollowUps = []
        isThinking = true

        Task {
            var turn: TwinChatTurn?

            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), let brainPipeline = pipeline as? FoundationTwinChat {
                turn = await brainPipeline.ask(text)
            }
            #endif

            if turn == nil {
                // Retrieval path — every device, no model required: semantic
                // search resolves the closest entries; the deterministic
                // composer quotes them verbatim with citations.
                let evidence = await evidenceAdapter.recall(query: text, topK: 3, dateRange: nil)
                turn = RetrievalAnswerComposer.compose(
                    question: text,
                    evidence: evidence,
                    twin: DigitalTwinEngine.shared,
                    profile: TwinChatProfile(from: LocalAIEngine.shared.userProfile))
            }

            isThinking = false
            withAnimation(.easeIn(duration: 0.2)) {
                messages.append(TwinChatMessage(text: turn?.answer ?? "",
                                                isUser: false,
                                                citations: turn?.citations ?? []))
            }
            latestFollowUps = turn?.suggestedFollowUps ?? []
        }
    }

    private func entry(for idString: String) -> DiaryEntry? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        request.fetchLimit = 1
        return (try? viewContext.fetch(request))?.first
    }
}

#Preview {
    NavigationView {
        TwinChatView()
    }
}
