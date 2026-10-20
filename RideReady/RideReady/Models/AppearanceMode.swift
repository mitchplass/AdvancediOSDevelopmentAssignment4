import SwiftUI

/// Light, dark, or whatever the iPhone is using.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// What to tell the rider the choice does.
    var detail: String {
        switch self {
        case .system:
            return "Uses the appearance from iPhone Settings."
        case .light:
            return "Uses a light appearance."
        case .dark:
            return "Uses a dark appearance."
        }
    }

    /// `nil` lets the system choose.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
