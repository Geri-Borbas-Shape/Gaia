import SwiftUI

extension Star {

    /// Approximate display colour from the BP−RP colour index.
    var color: Color {
        guard let colorIndex else { return .gray }
        switch colorIndex {
        case ..<0.0: return Color(red: 0.61, green: 0.70, blue: 1.00)
        case ..<0.5: return Color(red: 0.79, green: 0.84, blue: 1.00)
        case ..<0.8: return Color(red: 0.97, green: 0.97, blue: 1.00)
        case ..<1.2: return Color(red: 1.00, green: 0.93, blue: 0.70)
        case ..<1.8: return Color(red: 1.00, green: 0.78, blue: 0.48)
        default: return Color(red: 1.00, green: 0.58, blue: 0.40)
        }
    }
}
