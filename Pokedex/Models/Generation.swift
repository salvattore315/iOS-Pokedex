/// The nine game generations. Raw values are the PokéAPI generation IDs.
enum Generation: Int, CaseIterable, Identifiable, Sendable {
    case kanto = 1, johto, hoenn, sinnoh, unova, kalos, alola, galar, paldea

    var id: Int { rawValue }

    /// Region names are proper nouns and are not translated.
    var regionName: String {
        switch self {
        case .kanto: "Kanto"
        case .johto: "Johto"
        case .hoenn: "Hoenn"
        case .sinnoh: "Sinnoh"
        case .unova: "Unova"
        case .kalos: "Kalos"
        case .alola: "Alola"
        case .galar: "Galar"
        case .paldea: "Paldea"
        }
    }
}
