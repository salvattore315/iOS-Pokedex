import Foundation

/// Turns what the user typed and selected into a ``ListFilter``.
enum BuildListFilter {
    /// - Parameters:
    ///   - query: Name fragment or number. A leading `#` and leading zeros are ignored, so "#025" finds Pikachu.
    ///   - typeIDs: IDs of the selected type, or `nil` when no type is selected.
    ///   - generationIDs: IDs of the selected generation, or `nil` when none is selected.
    static func make(query: String, typeIDs: Set<Int>?, generationIDs: Set<Int>?) -> ListFilter {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        let digits = text.hasPrefix("#") ? String(text.dropFirst()) : text

        let ids: Set<Int>? = switch (typeIDs, generationIDs) {
        case let (type?, generation?): type.intersection(generation)
        case let (type?, nil): type
        case let (nil, generation?): generation
        case (nil, nil): nil
        }

        if let number = Int(digits) {
            return ListFilter(number: number, ids: ids)
        }
        return ListFilter(name: text, ids: ids)
    }
}
