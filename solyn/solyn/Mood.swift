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

    var displayName: String {
        switch self {
        case .none: return "No mood"
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .grateful: return "Grateful"
        case .excited: return "Excited"
        case .tired: return "Tired"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .angry: return "Angry"
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

    var color: Color {
        switch self {
        case .none: return .secondary
        case .happy: return .yellow
        case .calm: return .mint
        case .grateful: return .pink
        case .excited: return .orange
        case .tired: return .purple
        case .anxious: return .indigo
        case .sad: return .blue
        case .angry: return .red
        }
    }

    static var selectableMoods: [Mood] {
        allCases.filter { $0 != .none }
    }
}
