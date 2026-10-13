//
//  SuggestedMoodTests.swift
//  solynTests
//

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
        XCTAssertNil(SuggestedMood.dominantFeeling([.sadness: 0.5, .anger: 0.5]))
        XCTAssertEqual(SuggestedMood.dominantFeeling([.sadness: 0.6, .anger: 0.5, .neutral: 1]), .sadness,
                       "neutral is the absence of a feeling, never the winner")
    }

    func testTiredOnlyWhenNothingCompetes() {
        XCTAssertEqual(suggest(0, [:], "long day at work and I am so tired"), .tired)
        XCTAssertNil(suggest(0, [.joy: 0.3], "long day at work and I am so tired"))
        XCTAssertNil(suggest(0.3, [:], "long day at work and I am so tired"))
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

    func testNeverTouchesAMoodTheUserChose() {
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: "sad", isSuggested: false, userChose: true,
                                                  suggestion: .happy), .leave)
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: "", isSuggested: false, userChose: true,
                                                  suggestion: .happy), .leave,
                       "\"No mood\", picked on purpose, is a choice too")
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: "sad", isSuggested: false, userChose: false,
                                                  suggestion: .happy), .leave,
                       "a mood from before suggestions existed is the user's")
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: "", isSuggested: false, userChose: false,
                                                  suggestion: .happy), .leave)
    }

    func testFillsOnlyAnEmptyMood() {
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: nil, isSuggested: false, userChose: false,
                                                  suggestion: .calm), .suggest(.calm))
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: nil, isSuggested: false, userChose: false,
                                                  suggestion: nil), .leave)
    }

    func testOwnSuggestionFollowsTheWords() {
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: "calm", isSuggested: true, userChose: false,
                                                  suggestion: .sad), .suggest(.sad))
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: "calm", isSuggested: true, userChose: false,
                                                  suggestion: .calm), .leave)
        XCTAssertEqual(SuggestedMoodUpdate.decide(currentMood: "calm", isSuggested: true, userChose: false,
                                                  suggestion: nil), .clear,
                       "a suggestion the longer day no longer supports is withdrawn, not left standing")
    }

    func testStoreTracksSuggestedThenChosen() throws {
        let suite = "SuggestedMoodTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SuggestedMoodStore(defaults: defaults)
        let id = UUID()

        XCTAssertFalse(store.isSuggested(id))
        store.markSuggested(id)
        XCTAssertTrue(store.isSuggested(id))
        XCTAssertTrue(SuggestedMoodStore(defaults: defaults).isSuggested(id), "survives a relaunch")

        store.markChosenByUser(id)
        XCTAssertFalse(store.isSuggested(id))
        XCTAssertTrue(store.userChose(id))
        XCTAssertFalse(store.isSuggested(nil))
    }
}
