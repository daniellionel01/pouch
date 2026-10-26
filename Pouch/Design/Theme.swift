import PouchCore
import SwiftUI

/// Colors for one colorway. Accents are mid-tone on purpose so they read on
/// both the light and dark material.
struct Theme: Equatable {
    let id: ThemeID
    let name: String
    let accent: Color

    static func named(_ id: ThemeID) -> Theme {
        switch id {
        case .kangaroo: Theme(id: id, name: "Kangaroo", accent: Color(red: 0.91, green: 0.55, blue: 0.27))
        case .mint: Theme(id: id, name: "Mint", accent: Color(red: 0.20, green: 0.74, blue: 0.58))
        case .grape: Theme(id: id, name: "Grape", accent: Color(red: 0.56, green: 0.42, blue: 0.94))
        case .graphite: Theme(id: id, name: "Graphite", accent: Color(red: 0.48, green: 0.50, blue: 0.55))
        }
    }
}

extension EnvironmentValues {
    @Entry var theme = Theme.named(.kangaroo)
}
