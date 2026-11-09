import AVFoundation

/// Plays a Pokémon cry. PokéAPI serves cries as Ogg Vorbis, which AVFoundation decodes
/// natively only from iOS 18.4, so earlier versions do not show the button at all.
@MainActor
final class CryPlayer {
    static var isSupported: Bool {
        if #available(iOS 18.4, *) { true } else { false }
    }

    private var player: AVPlayer?

    func play(_ url: URL) {
        guard Self.isSupported else { return }
        let player = AVPlayer(url: url)
        self.player = player
        player.play()
    }
}
