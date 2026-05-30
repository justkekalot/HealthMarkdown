import Foundation

/// Logical grouping of metrics for both the UI and the generated Markdown.
enum HealthSection: String, CaseIterable, Identifiable {
    case activity
    case heart
    case body
    case vitals
    case respiratory
    case nutrition
    case sleep
    case mindfulness
    case mobility
    case audio
    case workouts
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activity: return "Activity"
        case .heart: return "Heart"
        case .body: return "Body Measurements"
        case .vitals: return "Vitals"
        case .respiratory: return "Respiratory"
        case .nutrition: return "Nutrition"
        case .sleep: return "Sleep"
        case .mindfulness: return "Mindfulness"
        case .mobility: return "Mobility"
        case .audio: return "Hearing"
        case .workouts: return "Workouts"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .activity: return "flame.fill"
        case .heart: return "heart.fill"
        case .body: return "figure.stand"
        case .vitals: return "waveform.path.ecg"
        case .respiratory: return "lungs.fill"
        case .nutrition: return "fork.knife"
        case .sleep: return "bed.double.fill"
        case .mindfulness: return "brain.head.profile"
        case .mobility: return "figure.walk"
        case .audio: return "ear.fill"
        case .workouts: return "figure.run"
        case .profile: return "person.crop.circle"
        }
    }

    /// Ordering used in the Markdown document.
    var sortIndex: Int {
        HealthSection.allCases.firstIndex(of: self) ?? 0
    }
}
