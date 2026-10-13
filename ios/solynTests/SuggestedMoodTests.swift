//
//  SuggestedMoodTests.swift
//  solynTests
//

import CoreData
import XCTest
import DailyVoxTwinEngine
@testable import solyn

/// The mapper is allowed to be quiet and not allowed to be wrong, so most of
/// these pin down the nils. They feed the pure `suggest(sentiment:emotions:
/// text:)` fixed signals rather than running NLTagger, whose scores can move
/// between OS releases; what is under test is the mapping, not Apple's model.
final class SuggestedMoodTests: XCTestCase {

    private let plain = "went to the market and then came home"

    private func suggest(_ sentiment: Double, _ emotions: [DetectedEmotion: Double] = [:],
                         _ text: String? = nil) -> Mood? {
        SuggestedMood.suggest(sentiment: sentiment, emotions: emotions, text: text ?? plain)
    }

    // MARK: Nothing to read

    func testEmptyTextSuggestsNothing() {
        XCTAssertNil(SuggestedMood.suggest(sentiment: 0.9, emotions: [.joy: 1], text: ""))
        XCTAssertNil(SuggestedMood.suggest(sentiment: 0.9, emotions: [.joy: 1], text: "   \n "))
        XCTAssertNil(SuggestedMood.suggest(for: ""), "the engine is never even asked about empty text")
    }

    func testTooFewWordsSuggestsNothing() {
        XCTAssertNil(SuggestedMood.suggest(sentiment: 0.9, emotions: [.joy: 1], text: "so happy today"),
                     "three words is not enough to tell someone how they felt")
    }

    func testNeutralSuggestsNothing() {
        XCTAssertNil(suggest(0))
        XCTAssertNil(suggest(0, [.neutral: 1]))
        XCTAssertNil(suggest(0.2, [.joy: 0.5]), "a lean below the threshold is not a mood")
        XCTAssertNil(suggest(-0.2, [.sadness: 0.5]))
    }

    // MARK: Thresholds

    func testThresholdIsInclusive() {
        XCTAssertEqual(suggest(SuggestedMood.leanThreshold, [.joy: 0.5]), .happy)
        XCTAssertNil(suggest(SuggestedMood.leanThreshold - 0.01, [.joy: 0.5]))
        XCTAssertEqual(suggest(-SuggestedMood.leanThreshold, [.sadness: 0.5]), .sad)
        XCTAssertNil(suggest(-SuggestedMood.leanThreshold + 0.01, [.sadness: 0.5]))
    }

    func testExcitedNeedsMoreThanALean() {
        XCTAssertEqual(suggest(0.7, [.anticipation: 0.5]), .excited)
        XCTAssertNil(suggest(0.45, [.anticipation: 0.5]),
                     "mildly positive and looking ahead is not excited")
    }

    // MARK: Agreement

    func testPositiveMapsByFeeling() {
        XCTAssertEqual(suggest(0.6, [.joy: 0.5]), .happy)
        XCTAssertEqual(suggest(0.6, [.trust: 0.5]), .calm)
        XCTAssertEqual(suggest(0.5, [:], "a slow morning and I felt calm the whole time"), .calm)
        XCTAssertEqual(suggest(0.6, [.joy: 0.5], "really grateful for my sister helping me today"), .grateful)
    }

    func testNegativeMapsByFeeling() {
        XCTAssertEqual(suggest(-0.6, [.sadness: 0.5]), .sad)
        XCTAssertEqual(suggest(-0.6, [.anger: 0.5]), .angry)
        XCTAssertEqual(suggest(-0.6, [.fear: 0.5]), .anxious)
        XCTAssertEqual(suggest(-0.6, [:], "long shift and I am completely exhausted now"), .tired)
    }

    func testSignalsThatDisagreeSuggestNothing() {
        XCTAssertNil(suggest(0.7, [.sadness: 0.5]), "positive words, sad feeling: no guess")
        XCTAssertNil(suggest(-0.7, [.joy: 0.5]), "negative words, joyful feeling: no guess")
    }

    func testPositiveWithNoKindSuggestsNothing() {
        XCTAssertNil(suggest(0.8), "positive, but nothing says happy rather than calm or grateful")
        XCTAssertNil(suggest(-0.8), "negative, but nothing says sad rather than angry or anxious")
    }

    func testTiedFeelingsSuggestNothing() {
        XCTAssertNil(suggest(-0.6, [.sadness: 0.5, .anger: 0.5]))
        XCTAssertNil(suggest(0.6, [.fear: 1, .joy: 1], "I feel blessed and grateful but anxious about money"),
                     "a tie is mixed feelings; a lexicon word must not pick one side")
        XCTAssertNil(suggest(-0.6, [.sadness: 1, .joy: 1], "long day and I am exhausted"),
                     "nor may the tired fallback")
        XCTAssertNil(SuggestedMood.dominantFeeling([.sadness: 0.5, .anger: 0.5]))
        XCTAssertEqual(SuggestedMood.dominantFeeling([.sadness: 0.6, .anger: 0.5, .neutral: 1]), .sadness,
                       "neutral is the absence of a feeling, never the winner")
    }

    func testTiredOnlyWhenNothingCompetes() {
        XCTAssertEqual(suggest(0, [:], "long day at work and I am so tired"), .tired)
        XCTAssertNil(suggest(0, [.joy: 0.3], "long day at work and I am so tired"))
        XCTAssertNil(suggest(0.3, [:], "long day at work and I am so tired"))
    }

    // MARK: Negation

    func testNegatedWordsAreNotSaid() {
        XCTAssertEqual(SuggestedMood.affirmed(in: "I am not sad, just tired"),
                       ["i", "am", "not", SuggestedMood.denied, "just", "tired"],
                       "a negation stops at the end of its clause")
        XCTAssertEqual(SuggestedMood.affirmed(in: "I didn\u{2019}t feel tired at all today"),
                       ["i", "didn't", SuggestedMood.denied, SuggestedMood.denied, SuggestedMood.denied, "all", "today"])
        XCTAssertEqual(SuggestedMood.affirmed(in: "can't wait for tomorrow"), ["can't", "wait", "for", "tomorrow"],
                       "\"can't wait\" is eagerness")
    }

    func testNegatedLexiconWordSuggestsNothing() {
        XCTAssertNil(suggest(-0.8, [:], "I'm not tired at all today, I slept really well"))
        XCTAssertNil(suggest(-0.8, [:], "I'm not exhausted and I feel ready for the week"))
        XCTAssertNil(suggest(0.6, [:], "never felt calm in that office at all"))
        XCTAssertEqual(suggest(-0.6, [:], "not a great week and I am so tired"), .tired,
                       "a negation elsewhere does not cancel what was said plainly")
    }

    /// The cases that came back as the very mood denied, through the real
    /// engine. Whatever the OS model scores, none of these may say it.
    func testRealEngineHonoursNegation() {
        XCTAssertNil(SuggestedMood.suggest(for: "I am not sad, I am actually doing fine today"))
        XCTAssertNil(SuggestedMood.suggest(for: "I'm not tired at all today, I slept really well"))
        XCTAssertNotEqual(SuggestedMood.suggest(for: "I'm not exhausted, I feel rested and ready for the week"),
                          .tired)
    }

    func testRealEngineMixedFeelingsSuggestNothing() {
        XCTAssertNil(SuggestedMood.suggest(for: "I feel blessed and grateful, but also really anxious about money"))
    }

    func testLexiconMatchesWholeWordsOnly() {
        XCTAssertNil(suggest(0.6, [:], "we watched the documentary contents of the box"),
                     "'contents' is not 'content'")
        XCTAssertEqual(SuggestedMood.tokens(in: "I can\u{2019}t — wait!"), ["i", "can't", "wait"])
    }

    /// End to end through the real engine. Only the direction is asserted —
    /// the OS model decides the score, and an older one may say nothing.
    func testRealEngineNeverFlipsTheDirection() {
        let warm = SuggestedMood.suggest(for: "I am so happy today, the whole family came over and it was wonderful")
        XCTAssertFalse([.sad, .angry, .anxious, .tired].contains(warm),
                       "a plainly happy entry must never come back as a low mood")
        let low = SuggestedMood.suggest(for: "I feel so sad and lonely tonight, I miss her and I cried for hours")
        XCTAssertFalse([.happy, .excited, .grateful, .calm].contains(low),
                       "a plainly sad entry must never come back as a good one")
    }

    // MARK: Never over the user

    private func decide(_ current: String?, suggested: String? = nil, _ suggestion: Mood?) -> SuggestedMoodUpdate {
        SuggestedMoodUpdate.decide(currentMood: current, lastSuggested: suggested, suggestion: suggestion)
    }

    func testNeverTouchesAMoodTheUserChose() {
        XCTAssertEqual(decide("sad", .happy), .leave)
        XCTAssertEqual(decide("", .happy), .leave, "\"No mood\", picked on purpose, is a choice too")
        XCTAssertEqual(decide("", suggested: "calm", .happy), .leave)
    }

    /// Device A suggested calm; on device B the user picked sad, and it synced
    /// back. The value no longer matches what A suggested, so it is the user's.
    func testAMoodChangedElsewhereIsTheUsers() {
        XCTAssertEqual(decide("sad", suggested: "calm", .calm), .leave)
        XCTAssertEqual(decide("sad", suggested: "calm", nil), .leave, "nor withdrawn")
    }

    func testFillsOnlyAnEmptyMood() {
        XCTAssertEqual(decide(nil, .calm), .suggest(.calm))
        XCTAssertEqual(decide(nil, nil), .leave)
        XCTAssertEqual(decide(nil, suggested: "calm", .sad), .suggest(.sad))
    }

    func testOwnSuggestionFollowsTheWords() {
        XCTAssertEqual(decide("calm", suggested: "calm", .sad), .suggest(.sad))
        XCTAssertEqual(decide("calm", suggested: "calm", .calm), .leave)
        XCTAssertEqual(decide("calm", suggested: "calm", nil), .clear,
                       "a suggestion the longer day no longer supports is withdrawn, not left standing")
    }

    /// The marker lives on the entry, so it syncs and restores with the mood.
    func testEntryKnowsSuggestedFromChosen() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let e = DiaryEntry(context: context)
        e.id = UUID()
        e.text = "I am so happy today, the whole family came over and it was wonderful"
        XCTAssertFalse(e.isMoodSuggested)

        e.mood = "happy"
        e.suggestedMood = "happy"
        XCTAssertTrue(e.isMoodSuggested)
        XCTAssertNil(e.userMood, "a suggestion is never reported as the user's mood")

        // Another device, or an older build, sets the mood without knowing
        // about suggestions: it is the user's from then on.
        e.mood = "sad"
        XCTAssertFalse(e.isMoodSuggested)
        XCTAssertEqual(e.userMood, "sad")
        XCTAssertFalse(e.refreshSuggestedMood(), "and it is never written over")
        XCTAssertEqual(e.mood, "sad")

        e.setMoodChosenByUser("happy")
        XCTAssertNil(e.suggestedMood)
        XCTAssertEqual(e.userMood, "happy", "confirming the suggested value makes it theirs")
        try context.save()
    }
}
