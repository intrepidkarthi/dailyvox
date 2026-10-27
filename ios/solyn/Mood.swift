import SwiftUI

enum Mood: String, CaseIterable, Identifiable {
    case none = ""
    case happy = "happy"
    case calm = "calm"
    case grateful = "grateful"
    case excited = "excited"
    case tired = "tired"
    case anxious = "anxious"
    case sad = "sad"
    case angry = "angry"

    var id: String { rawValue }

    /// The mood's name as the reader sees it. The raw value, not this, is what
    /// is stored, exported and compared.
    ///
    /// Callers also lower- and upper-case it inside sentences ("Sounds calm —
    /// tap to change", "SOUNDS CALM?"), so a translation must be a word that
    /// still reads correctly in lower case mid-sentence.
    var displayName: String {
        switch self {
        case .none: return String(localized: "No mood", comment: "Mood picker and entry detail: the choice that clears the mood. About 12 characters.")
        case .happy: return String(localized: "Happy", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling happy'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        case .calm: return String(localized: "Calm", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling calm'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        case .grateful: return String(localized: "Grateful", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling grateful'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        case .excited: return String(localized: "Excited", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling excited'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        case .tired: return String(localized: "Tired", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling tired'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        case .anxious: return String(localized: "Anxious", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling anxious'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        case .sad: return String(localized: "Sad", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling sad'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        case .angry: return String(localized: "Angry", comment: "Mood name. Shown alone (picker chip, stats row) and lower-cased inside sentences such as 'Feeling angry'. An adjective about the user: keep it gender-neutral. About 10 characters.")
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.dashed"
        case .happy: return "sun.max.fill"
        case .calm: return "leaf.fill"
        case .grateful: return "heart.fill"
        case .excited: return "star.fill"
        case .tired: return "moon.zzz.fill"
        case .anxious: return "wind"
        case .sad: return "cloud.rain.fill"
        case .angry: return "flame.fill"
        }
    }

    /// Mood colours, drawn from the design system rather than from UIKit.
    ///
    /// These were `.yellow`, `.mint`, `.pink`, `.orange`, `.purple`, `.indigo`,
    /// `.blue` and `.red` — eight system colours, none of them in the palette.
    /// They are the most-repeated colour in the app: a rail down the left edge
    /// of every row in the Journal. A magenta and a cyan running down a cream
    /// page is the one place "Evergreen & Gold Hour" was being contradicted at
    /// scale, on the screen people look at most.
    ///
    /// The mapping runs warm-to-cool along valence, which is what the rail is
    /// actually reporting: gold and terracotta for the good days, sage for the
    /// even ones, navy and slate for the flat ones, coral for anger — the same
    /// coral that means "recording", the one alarm colour the palette has.
    var color: Color {
        switch self {
        case .none:     return DS.Palette.inkMute
        case .happy:    return DS.Palette.gold
        case .excited:  return DS.Palette.terracotta
        case .grateful: return DS.Palette.sagePositive
        case .calm:     return DS.Palette.forest
        case .tired:    return DS.Palette.inkSoft
        case .anxious:  return DS.Palette.starBlue
        case .sad:      return DS.Palette.navySurface
        case .angry:    return DS.Palette.coral
        }
    }

    static var selectableMoods: [Mood] {
        allCases.filter { $0 != .none }
    }
}
