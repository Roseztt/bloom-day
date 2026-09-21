import Foundation
import SwiftData
import SwiftUI

/// A longer-running intention that isn't a single dated task — "read 4 books this
/// month", "keep a consistent study routine".
@Model
final class Goal {
    var uid: UUID = UUID()
    var title: String = ""
    var symbol: String = "target"
    /// 0 means this goal isn't counted, it just has a status.
    var targetCount: Int = 0
    var currentCount: Int = 0
    var statusRaw: Int = GoalStatus.inProgress.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isArchived: Bool = false

    init(
        title: String = "",
        symbol: String = "target",
        targetCount: Int = 0,
        currentCount: Int = 0,
        status: GoalStatus = .inProgress
    ) {
        self.uid = UUID()
        self.title = title
        self.symbol = symbol
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
    }
}

enum GoalStatus: Int, CaseIterable, Identifiable {
    case inProgress = 0
    case onTrack = 1
    case achieved = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .inProgress: return "In Progress"
        case .onTrack: return "On Track"
        case .achieved: return "Achieved"
        }
    }

    var tint: Color {
        switch self {
        case .inProgress: return Bloom.pink
        case .onTrack: return Bloom.mint
        case .achieved: return Bloom.peach
        }
    }

    var soft: Color {
        switch self {
        case .inProgress: return Bloom.pinkSoft
        case .onTrack: return Bloom.mintSoft
        case .achieved: return Bloom.peachSoft
        }
    }
}

extension Goal {
    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    var isCounted: Bool { targetCount > 0 }

    var progress: Double {
        guard isCounted else { return status == .achieved ? 1 : 0 }
        return min(1, Double(currentCount) / Double(targetCount))
    }

    /// "2 / 4" for counted goals, otherwise the status text.
    var trailingLabel: String {
        isCounted ? "\(currentCount) / \(targetCount)" : status.label
    }

    var displayTitle: String {
        title.isEmpty ? "Untitled goal" : title
    }
}
