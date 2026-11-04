//
//  EntryLanguage.swift
//  solyn
//
//  Which entries the English-only readers are allowed to read.
//

import Foundation
import NaturalLanguage

/// Several things the app says about an entry are read from English word
/// lists: the suggested mood, the reflection shown after saving, and the
/// "gentle enough to ask about" check behind the daily question. Fed a
/// Spanish or Hindi entry they do not fail. They answer, and they answer
/// wrongly: "calm mind" on an entry about a funeral, a question about a name
/// from an entry the sensitive-word list could not read.
///
/// Until those readers learn other languages, the rule is that they stay
/// QUIET outside English. This decides which entries count as English.
///
/// English behaviour must not move, so the bias is deliberate: an entry is
/// treated as English unless there is real evidence it is not — mostly
/// non-Latin letters, or a recogniser confident of another language on an
/// entry long enough to judge. A two-word English note the recogniser is
/// unsure about stays English, exactly as before.
enum EntryLanguage {

    /// Below this many words the recogniser's guess is not trusted to switch
    /// anything off; short entries keep the English path.
    static let minimumWordsToJudge = 3
    /// How sure the recogniser must be of another language.
    static let otherLanguageConfidence = 0.6

    /// Whether `text` should be read by the English-only features.
    static func isEnglish(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        // Script first: Devanagari, Tamil, CJK, Arabic, Cyrillic… cannot be
        // English, however short, and the recogniser is not needed to say so.
        var latin = 0, other = 0
        for scalar in trimmed.unicodeScalars where scalar.properties.isAlphabetic {
            if isLatin(scalar) { latin += 1 } else { other += 1 }
        }
        if other > latin { return false }
        if latin == 0 { return true }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).count
        guard words >= minimumWordsToJudge else { return true }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let top = recognizer.languageHypotheses(withMaximum: 1).first else { return true }
        if top.key == .english { return true }
        return top.value < otherLanguageConfidence
    }

    private static func isLatin(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0041...0x024F,   // Basic Latin letters through Latin Extended-B
             0x1E00...0x1EFF,   // Latin Extended Additional (Vietnamese…)
             0x2C60...0x2C7F,   // Latin Extended-C
             0xA720...0xA7FF,   // Latin Extended-D
             0xFF21...0xFF5A:   // Fullwidth Latin
            return true
        default:
            return false
        }
    }
}
