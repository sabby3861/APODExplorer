//
//  PreviewMocks.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 24/04/2026.
//
//  Mock dependencies for SwiftUI previews. DEBUG-only so nothing here ends
//  up in Release. Test code has its own mocks in the test target — the two
//  overlap in purpose but not in shape.
//

#if DEBUG
import Foundation
import UIKit

enum PreviewMocks {

    // MARK: - Sample data

    static let sampleImageAPOD = APOD(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        title: "The Horsehead Nebula in Orion",
        explanation: "One of the most identifiable nebulae in the sky, the Horsehead Nebula in Orion, is part of a large, dark, molecular cloud. Also known as Barnard 33, the unusual shape was first discovered on a photographic plate in the late 1800s.",
        mediaType: .image,
        url: URL(string: "https://apod.nasa.gov/apod/image/preview.jpg") ?? DefaultAPODService.defaultBaseURL,
        hdURL: nil,
        copyright: "NASA"
    )

    static let sampleVideoAPOD = APOD(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        title: "Perseverance's Mars Landing",
        explanation: "What would it look like to land on Mars? NASA's Perseverance rover has provided unprecedented views.",
        mediaType: .video,
        url: URL(string: "https://www.youtube.com/embed/4czjS9h4Fpg") ?? DefaultAPODService.defaultBaseURL,
        hdURL: nil,
        copyright: nil
    )

    // MARK: - Loaders

    static let imageLoader: MediaLoading = PreviewMediaLoader()

    /// Default repository for previews that don't care about state — renders
    /// the Today tab as if loaded with the sample image.
    static let previewRepository: APODRepository = PreviewRepository(
        apodResult: .success(APODResult(apod: sampleImageAPOD, source: .fresh))
    )

    // MARK: - View models for each preview state

    @MainActor
    static func loadedImageViewModel() -> TodayViewModel {
        let vm = TodayViewModel(repository: PreviewRepository(
            apodResult: .success(APODResult(apod: sampleImageAPOD, source: .fresh))
        ))
        Task { await vm.onAppear() }
        return vm
    }

    @MainActor
    static func loadedVideoViewModel() -> TodayViewModel {
        let vm = TodayViewModel(repository: PreviewRepository(
            apodResult: .success(APODResult(apod: sampleVideoAPOD, source: .fresh))
        ))
        Task { await vm.onAppear() }
        return vm
    }

    @MainActor
    static func loadingViewModel() -> TodayViewModel {
        // Never resolves — stays on .loading forever for the preview.
        TodayViewModel(repository: PreviewRepository(apodResult: .pending))
    }

    @MainActor
    static func failedViewModel() -> TodayViewModel {
        let vm = TodayViewModel(repository: PreviewRepository(
            apodResult: .failure(APODError.network(underlying: URLError(.notConnectedToInternet)))
        ))
        Task { await vm.onAppear() }
        return vm
    }

    @MainActor
    static func cachedViewModel() -> TodayViewModel {
        let vm = TodayViewModel(repository: PreviewRepository(
            apodResult: .success(APODResult(apod: sampleImageAPOD, source: .cache))
        ))
        Task { await vm.onAppear() }
        return vm
    }
}

// MARK: - Preview repository

private actor PreviewRepository: APODRepository {
    enum ResolvedResult: Sendable {
        case success(APODResult)
        case failure(APODError)
        case pending  // never resolves — used for the "loading" preview
    }

    let apodResult: ResolvedResult

    init(apodResult: ResolvedResult) {
        self.apodResult = apodResult
    }

    func fetchAPOD(for date: APODDate) async throws -> APODResult {
        switch apodResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        case .pending:
            // Never resolves — keeps the view on the loading state.
            try await Task.sleep(nanoseconds: .max)
            throw APODError.unknown(description: "unreachable")
        }
    }

    func fetchMedia(for apod: APOD) async throws -> Data {
        await PreviewPlaceholderImage.bytes
    }
}

// MARK: - Preview media loader

private struct PreviewMediaLoader: MediaLoading {
    func fetchMedia(for apod: APOD) async throws -> Data {
        // SF Symbol as a placeholder so previews render the loaded state,
        // not the "couldn't load image" failure state. We can't hit the
        // real NASA URL from the preview canvas reliably.
        await PreviewPlaceholderImage.bytes
    }
}

@MainActor
private enum PreviewPlaceholderImage {
    static let bytes: Data = {
        let config = UIImage.SymbolConfiguration(pointSize: 120, weight: .light)
        let image = UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: config)
        return image?.pngData() ?? Data()
    }()
}
#endif
