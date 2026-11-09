import Foundation
import SwiftData

/// One row of the local search index: the ID and name of every Pokémon.
@Model
final class PokemonIndexEntry {
    @Attribute(.unique) var id: Int
    var name: String

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    convenience init(_ summary: PokemonSummary) {
        self.init(id: summary.id, name: summary.name)
    }

    var summary: PokemonSummary {
        PokemonSummary(id: id, name: name)
    }
}
