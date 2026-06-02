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

        static func fromHSL(hue: Double, saturation: Double, lightness: Double) -> Stop {
            let h = hue, s = saturation, l = lightness
            let c = (1 - abs(2 * l - 1)) * s
            let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
            let m = l - c / 2
            let (r1, g1, b1): (Double, Double, Double)
            switch Int(h * 6) % 6 {
            case 0: (r1, g1, b1) = (c, x, 0)
            case 1: (r1, g1, b1) = (x, c, 0)
            case 2: (r1, g1, b1) = (0, c, x)
            case 3: (r1, g1, b1) = (0, x, c)
            case 4: (r1, g1, b1) = (x, 0, c)
            default: (r1, g1, b1) = (c, 0, x)
            }
            return Stop(red: r1 + m, green: g1 + m, blue: b1 + m, alpha: 1)
        }
    }

    var id: String
    var name: String
    var primary: Stop
    var secondary: Stop
    var accent: Stop
    var isBuiltIn: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, primary, secondary, accent, isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        primary = try container.decode(Stop.self, forKey: .primary)
        secondary = try container.decode(Stop.self, forKey: .secondary)
        accent = try container.decode(Stop.self, forKey: .accent)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    init(id: String = UUID().uuidString, name: String, primary: Stop, secondary: Stop, accent: Stop, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.isBuiltIn = isBuiltIn
    }

    static func fromHSL(name: String, primaryHue: Double, secondaryHue: Double, accentHue: Double) -> BrowserTheme {
        BrowserTheme(
            name: name,
            primary: Stop.fromHSL(hue: primaryHue, saturation: 0.6, lightness: 0.35),
            secondary: Stop.fromHSL(hue: secondaryHue, saturation: 0.5, lightness: 0.5),
            accent: Stop.fromHSL(hue: accentHue, saturation: 0.5, lightness: 0.7)
        )
    }

    static let builtIns: [BrowserTheme] = [
        .init(
            id: "desert",
            name: "Desert",
            primary: .init(red: 0.72, green: 0.45, blue: 0.27, alpha: 1),
            secondary: .init(red: 0.95, green: 0.74, blue: 0.45, alpha: 1),
            accent: .init(red: 0.20, green: 0.18, blue: 0.38, alpha: 1),
            isBuiltIn: true
        ),
        .init(
            id: "forest",
            name: "Forest",
            primary: .init(red: 0.10, green: 0.29, blue: 0.22, alpha: 1),
            secondary: .init(red: 0.38, green: 0.54, blue: 0.36, alpha: 1),
            accent: .init(red: 0.63, green: 0.75, blue: 0.68, alpha: 1),
            isBuiltIn: true
        ),
        .init(
            id: "ocean",
            name: "Ocean",
            primary: .init(red: 0.03, green: 0.22, blue: 0.32, alpha: 1),
            secondary: .init(red: 0.09, green: 0.50, blue: 0.58, alpha: 1),
            accent: .init(red: 0.77, green: 0.92, blue: 0.92, alpha: 1),
            isBuiltIn: true
        ),
        .init(
            id: "aurora",
            name: "Aurora",
            primary: .init(red: 0.08, green: 0.10, blue: 0.26, alpha: 1),
            secondary: .init(red: 0.22, green: 0.72, blue: 0.54, alpha: 1),
            accent: .init(red: 0.64, green: 0.42, blue: 0.88, alpha: 1),
            isBuiltIn: true
        ),
        .init(
            id: "dusk",
            name: "Dusk",
            primary: .init(red: 0.25, green: 0.16, blue: 0.28, alpha: 1),
            secondary: .init(red: 0.74, green: 0.36, blue: 0.46, alpha: 1),
            accent: .init(red: 0.93, green: 0.67, blue: 0.35, alpha: 1),
            isBuiltIn: true
        ),
        .init(
            id: "mountain",
            name: "Mountain",
            primary: .init(red: 0.23, green: 0.28, blue: 0.30, alpha: 1),
            secondary: .init(red: 0.35, green: 0.55, blue: 0.68, alpha: 1),
            accent: .init(red: 0.87, green: 0.92, blue: 0.94, alpha: 1),
            isBuiltIn: true
        )
    ]
}
