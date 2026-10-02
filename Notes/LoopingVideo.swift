//
//  LoopingVideo.swift
//  Notes
//
//  Muted, endlessly looping video from the app bundle (used by the paywall).
//

import SwiftUI
import AVFoundation

struct LoopingVideo: View {
    let resource: String

    var body: some View {
        if let url = Bundle.main.url(forResource: resource, withExtension: "mp4") {
            PlayerLayerView(url: url)
        } else {
            Color.clear
        }
    }
}

final class LoopingPlayer {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }
}

#if os(macOS)
private struct PlayerLayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let looping = LoopingPlayer(url: url)
        let layer = AVPlayerLayer(player: looping.player)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        view.wantsLayer = true
        context.coordinator.looping = looping
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looping: LoopingPlayer?
    }
}
#else
private struct PlayerLayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        let looping = LoopingPlayer(url: url)
        view.playerLayer.player = looping.player
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.looping = looping
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looping: LoopingPlayer?
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
#endif
