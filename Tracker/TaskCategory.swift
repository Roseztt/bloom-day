import SwiftUI

enum TaskCategory: Int, CaseIterable, Identifiable {
    case school = 0
    case personal = 1
    case work = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .school: return "School"
        case .personal: return "Personal"
        case .work: return "Work"
        }
    }

    var symbol: String {
        switch self {
        case .school: return "graduationcap.fill"
        case .personal: return "heart.fill"
        case .work: return "laptopcomputer"
        }
    }

    var tint: Color {
        switch self {
        case .school: return Bloom.lavender
        case .personal: return Bloom.mint
        case .work: return Bloom.peach
        }
    }

    var soft: Color {
        switch self {
        case .school: return Bloom.lavenderSoft
        case .personal: return Bloom.mintSoft
        case .work: return Bloom.peachSoft
        }
    }
}

/// What the row badge says. Derived rather than stored, so it can never drift
/// out of sync with the dates.
enum TaskStatus {
    case completed
    case inProgress
    case overdue
    case pending

    var label: String {
        switch self {
        case .completed: return "Completed"
        case .inProgress: return "In Progress"
        case .overdue: return "Overdue"
        case .pending: return "Pending"
        }
    }

    var tint: Color {
        switch self {
        case .completed: return Bloom.mint
        case .inProgress: return Bloom.pink
        case .overdue: return Bloom.pink
        case .pending: return Bloom.lavender
        }
    }

    var soft: Color {
        switch self {
        case .completed: return Bloom.mintSoft
        case .inProgress: return Bloom.pinkSoft
        case .overdue: return Bloom.pinkSoft
        case .pending: return Bloom.lavenderSoft
        }
    }
}
