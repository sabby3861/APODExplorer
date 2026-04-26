//
//  MediaView.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 26/04/2026.
//
//  Renders the APOD media. Image path loads bytes through MediaLoading
//  (which hits the on-disk cache). Video path branches between AVPlayer
//  and WKWebView depending on the URL host — YouTube/Vimeo embeds aren't
//  playable by AVPlayer.
//

import SwiftUI
import AVKit
import WebKit

struct MediaView: View {
    let apod: APOD
    let mediaLoader: MediaLoading
    
    var body: some View {
        Group {
            switch apod.mediaType {
            case .image:
                APODImageView(apod: apod, mediaLoader: mediaLoader)
            case .video:
                APODVideoView(apod: apod)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0/10.0, contentMode: .fit)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Image

private struct APODImageView: View {
    let apod: APOD
    let mediaLoader: MediaLoading
    
    @State private var phase: LoadPhase = .loading
    
    enum LoadPhase {
        case loading
        case loaded(UIImage)
        case failed
    }
    
    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading image")
                
            case .loaded(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(apod.title)
                    .accessibilityAddTraits(.isImage)
                
            case .failed:
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Couldn't load image")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Couldn't load image for \(apod.title)")
            }
        }
        .task(id: apod.url) {
            await load()
        }
    }
    
    @MainActor
    private func load() async {
        phase = .loading
        do {
            let data = try await mediaLoader.fetchMedia(for: apod)
            // Decode off the main actor. For a 4K APOD this saves ~50-100ms
            // of main-thread stall that would otherwise show as a scroll hitch.
            let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
            if let image = decoded {
                phase = .loaded(image)
            } else {
                phase = .failed
            }
        } catch {
            phase = .failed
        }
    }
}

// MARK: - Video

private struct APODVideoView: View {
    let apod: APOD
    
    var body: some View {
        if isEmbeddedPlayer(apod.url) {
            EmbeddedVideoView(url: apod.url)
                .accessibilityLabel("Video: \(apod.title)")
                .accessibilityAddTraits(.startsMediaSession)
        } else {
            NativeVideoPlayer(url: apod.url)
                .accessibilityLabel("Video: \(apod.title)")
                .accessibilityAddTraits(.startsMediaSession)
        }
    }
    
    private func isEmbeddedPlayer(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("youtube.com")
        || host.contains("youtu.be")
        || host.contains("vimeo.com")
    }
}

// Holds the AVPlayer in @State so it isn't recreated on every body
// re-evaluation. Without this wrapper, any upstream state change
// restarts the video from zero.
private struct NativeVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer
    
    init(url: URL) {
        self.url = url
        self._player = State(initialValue: AVPlayer(url: url))
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .onChange(of: url) { _, newURL in
                player.replaceCurrentItem(with: AVPlayerItem(url: newURL))
            }
    }
}

private struct EmbeddedVideoView: UIViewRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    
    // updateUIView fires on every SwiftUI invalidation. Guarding against the
    // same-URL case prevents the embed from reloading on every parent render.
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedURL != url else { return }
        context.coordinator.lastLoadedURL = url
        webView.load(URLRequest(url: url))
    }
    
    final class Coordinator {
        var lastLoadedURL: URL?
    }
}

// MARK: - Previews

#Preview("Image") {
    MediaView(
        apod: PreviewMocks.sampleImageAPOD,
        mediaLoader: PreviewMocks.imageLoader
    )
    .padding()
}

#Preview("Video (YouTube embed)") {
    MediaView(
        apod: PreviewMocks.sampleVideoAPOD,
        mediaLoader: PreviewMocks.imageLoader
    )
    .padding()
}
