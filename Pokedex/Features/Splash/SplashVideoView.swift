import AVFoundation
import SwiftUI

/// Plays the bundled splash video once, light or dark following the system theme,
/// and calls `onFinish` when it ends.
///
/// The background uses the same `LaunchBackground` color as the launch screen, so the
/// hand-off from the system launch screen to the first video frame is seamless.
struct SplashVideoView: View {
    /// The videos last 4.4 s. If playback stalls or fails, the splash closes anyway after this.
    static let maxDuration: Duration = .seconds(6)

    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player: AVPlayer?
    @State private var didFinish = false

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            if let player {
                PlayerLayerView(player: player).ignoresSafeArea()
            }
        }
        .accessibilityHidden(true)
        .task { await play() }
        .task {
            try? await Task.sleep(for: Self.maxDuration)
            finish()
        }
    }

    private func play() async {
        let name = colorScheme == .dark ? "SplashDark" : "SplashLight"
        guard !reduceMotion, let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
            finish()
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        self.player = player
        player.play()

        for await _ in NotificationCenter.default.notifications(named: AVPlayerItem.didPlayToEndTimeNotification, object: item) {
            break
        }
        finish()
    }

    /// Calls `onFinish` once, whichever path gets here first.
    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}

/// Wraps `AVPlayerLayer` so the video fills the screen with `.resizeAspectFill`.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        // The layer class is fixed above, so the cast cannot fail.
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
