import SwiftUI

/// The 18 type colors. They are the same in light and dark mode.
///
/// Raw values match the API type names so the app can map its own type enum with `TypeTint(rawValue:)`.
public enum TypeTint: String, CaseIterable, Sendable {
    case normal, fire, water, grass, electric, ice, fighting, poison, ground
    case flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy

    public var color: Color {
        switch self {
        case .normal: Color(hex: 0xA8A77A)
        case .fire: Color(hex: 0xEE8130)
        case .water: Color(hex: 0x6390F0)
        case .grass: Color(hex: 0x7AC74C)
        case .electric: Color(hex: 0xF7D02C)
        case .ice: Color(hex: 0x96D9D6)
        case .fighting: Color(hex: 0xC22E28)
        case .poison: Color(hex: 0xA33EA1)
        case .ground: Color(hex: 0xE2BF65)
        case .flying: Color(hex: 0xA98FF3)
        case .psychic: Color(hex: 0xF95587)
        case .bug: Color(hex: 0xA6B91A)
        case .rock: Color(hex: 0xB6A136)
        case .ghost: Color(hex: 0x735797)
        case .dragon: Color(hex: 0x6F35FC)
        case .dark: Color(hex: 0x705746)
        case .steel: Color(hex: 0xB7B7CE)
        case .fairy: Color(hex: 0xD685AD)
        }
    }

    /// Text color with enough contrast on top of ``color``.
    public var onColor: Color {
        switch self {
        case .normal, .electric, .ice, .ground, .steel: Color(hex: 0x16161A)
        default: .white
        }
    }
}

extension Color {
    /// Builds an sRGB color from a hex value such as `0xC8102E`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
