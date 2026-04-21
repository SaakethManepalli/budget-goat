import SwiftUI
import BudgetCore

/// SensoryFeedback specifications that correlate haptic weight to
/// transaction value. Apple's Wallet app uses a similar ladder.
public enum HapticWeight {
    /// Interaction weight derived from transaction amount in base currency.
    /// Thresholds use rough psychophysical buckets — "coffee", "lunch",
    /// "groceries", "rent".
    public static func feedback(for amount: Decimal) -> SensoryFeedback {
        let abs = abs((amount as NSDecimalNumber).doubleValue)
        switch abs {
        case   0..<10:    return .selection     // trivial: just a click
        case  10..<50:    return .impact(weight: .light)
        case  50..<250:   return .impact(weight: .medium)
        case 250..<1_000: return .impact(weight: .heavy)
        default:          return .success       // rent-sized: solid dual-tap
        }
    }

    /// Sync completion haptic scales with volume of changes.
    public static func feedback(for summary: SyncSummary) -> SensoryFeedback {
        switch summary.totalTouched {
        case 0:      return .selection
        case 1..<5:  return .impact(weight: .light)
        case 5..<25: return .success
        default:     return .success
        }
    }

    public static let budgetExceeded: SensoryFeedback = .warning
    public static let navigation: SensoryFeedback     = .selection
    public static let linkSuccess: SensoryFeedback    = .success
}

// Consumers call `.sensoryFeedback(HapticWeight.feedback(for: amount), trigger: ...)`
// directly on a view. No custom wrapper needed — SwiftUI's built-in
// `sensoryFeedback(_:trigger:)` does the plumbing.
