import SwiftUI

extension Star {

    /// Temperature-based display colour shared with the 3D map.
    var color: Color {
        let rgb = appearance.color
        return Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }
}
