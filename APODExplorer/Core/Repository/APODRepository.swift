//
//  APODRepository.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 24/04/2026.
//
///  Coordinates the APOD service and the on-disk cache. Owns the offline
//  fallback rule: if the network is unreachable or the service fails, return
//  whatever APOD is in the cache (regardless of date). The view model marks
//  cached results so the UI can show an offline badge.
//

import Foundation

protocol APODRepository: MediaLoading, Sendable {
    func fetchAPOD(for date: APODDate) async throws -> APODResult
}

// Narrow protocol for the view layer — MediaView only needs to fetch bytes,
// not the full repository surface.
protocol MediaLoading: Sendable {
    func fetchMedia(for apod: APOD) async throws -> Data
}

struct APODResult: Equatable, Sendable {
    enum Source: Sendable, Equatable {
        case fresh
        case cache
    }
    
    let apod: APOD
    let source: Source
}

actor DefaultAPODRepository: APODRepository {
    private let service: APODService
    private let networkClient: NetworkClient
    private let metadataStore: APODMetadataStore
    private let mediaCache: APODMediaCache
    private let networkMonitor: NetworkMonitor
    
    init(
        service: APODService,
        networkClient: NetworkClient,
        metadataStore: APODMetadataStore,
        mediaCache: APODMediaCache,
        networkMonitor: NetworkMonitor
    ) {
        self.service = service
        self.networkClient = networkClient
        self.metadataStore = metadataStore
        self.mediaCache = mediaCache
        self.networkMonitor = networkMonitor
    }
    
    func fetchAPOD(for date: APODDate) async throws -> APODResult {
        // If we already know we're offline, skip the timeout. Try the
        // exact-date cache first; fall back to the most recently saved
        // entry to honour the brief's "last service call should be loaded
        // if subsequent calls fail" guarantee.
        if await !networkMonitor.isReachable {
            if let cached = await cachedResult(for: date) {
                return cached
            }
            throw APODError.network(underlying: URLError(.notConnectedToInternet))
        }
        
        do {
            let fresh = try await service.fetchAPOD(for: date)
            await metadataStore.save(fresh)
            return APODResult(apod: fresh, source: .fresh)
        } catch {
            if let cached = await cachedResult(for: date) {
                return cached
            }
            if let apodError = error as? APODError {
                throw apodError
            }
            throw APODError.unknown(description: error.localizedDescription)
        }
    }
    
    /// Looks up cache for the requested date first; if not found, returns
    /// the most recently saved entry. Either way, the source is tagged as
    /// `.cache` so the UI can display the offline badge.
    private func cachedResult(for date: APODDate) async -> APODResult? {
        if let exact = await metadataStore.load(for: date) {
            return APODResult(apod: exact, source: .cache)
        }
        if let latest = await metadataStore.loadLatest() {
            return APODResult(apod: latest, source: .cache)
        }
        return nil
    }
    
    func fetchMedia(for apod: APOD) async throws -> Data {
        let url = apod.preferredMediaURL
        
        if let cached = await mediaCache.data(for: url) {
            return cached
        }
        
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await networkClient.data(from: url)
        } catch let error as APODError {
            throw error
        } catch {
            throw APODError.unknown(description: error.localizedDescription)
        }
        
        guard (200..<300).contains(response.statusCode) else {
            throw APODError.serverError(status: response.statusCode)
        }
        
        await mediaCache.store(data, for: url)
        return data
    }
}
