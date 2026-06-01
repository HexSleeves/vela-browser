import SwiftUI

struct BrowserTheme: Identifiable, Codable, Equatable {
    struct Stop: Codable, Equatable {
        var red: Double
        var green: Double
        var blue: Double
        var alpha: Double

        var color: Color {
            Color(red: red, green: green, blue: blue, opacity: alpha)
        }
    }

    var id: String
    var name: String
    var primary: Stop
    var secondary: Stop
    var accent: Stop

    static let builtIns: [BrowserTheme] = [
        .init(
            id: "desert",
            name: "Desert",
            primary: .init(red: 0.72, green: 0.45, blue: 0.27, alpha: 1),
            secondary: .init(red: 0.95, green: 0.74, blue: 0.45, alpha: 1),
            accent: .init(red: 0.20, green: 0.18, blue: 0.38, alpha: 1)
        ),
        .init(
            id: "forest",
            name: "Forest",
            primary: .init(red: 0.10, green: 0.29, blue: 0.22, alpha: 1),
            secondary: .init(red: 0.38, green: 0.54, blue: 0.36, alpha: 1),
            accent: .init(red: 0.63, green: 0.75, blue: 0.68, alpha: 1)
        ),
        .init(
            id: "ocean",
            name: "Ocean",
            primary: .init(red: 0.03, green: 0.22, blue: 0.32, alpha: 1),
            secondary: .init(red: 0.09, green: 0.50, blue: 0.58, alpha: 1),
            accent: .init(red: 0.77, green: 0.92, blue: 0.92, alpha: 1)
        ),
        .init(
            id: "aurora",
            name: "Aurora",
            primary: .init(red: 0.08, green: 0.10, blue: 0.26, alpha: 1),
            secondary: .init(red: 0.22, green: 0.72, blue: 0.54, alpha: 1),
            accent: .init(red: 0.64, green: 0.42, blue: 0.88, alpha: 1)
        ),
        .init(
            id: "dusk",
            name: "Dusk",
            primary: .init(red: 0.25, green: 0.16, blue: 0.28, alpha: 1),
            secondary: .init(red: 0.74, green: 0.36, blue: 0.46, alpha: 1),
            accent: .init(red: 0.93, green: 0.67, blue: 0.35, alpha: 1)
        ),
        .init(
            id: "mountain",
            name: "Mountain",
            primary: .init(red: 0.23, green: 0.28, blue: 0.30, alpha: 1),
            secondary: .init(red: 0.35, green: 0.55, blue: 0.68, alpha: 1),
            accent: .init(red: 0.87, green: 0.92, blue: 0.94, alpha: 1)
        )
    ]
}
