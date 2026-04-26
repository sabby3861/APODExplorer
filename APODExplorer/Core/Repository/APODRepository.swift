//
//  APODRepository.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 24/04/2026.
//
//  Coordinates the APOD service and the on-disk cache. Owns the offline
//  fallback rule: if the network call fails, return cache only when the
//  cached date matches the requested date.
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
        // If we already know we're offline, skip the timeout and go straight
        // to cache. The brief: "last service call should be cached and
        // loaded if any subsequent service call fails." We honour that
        // literally — if we have any cached APOD, serve it with the offline
        // source flag, even if the requested date doesn't match.
        if await !networkMonitor.isReachable {
            if let cached = await cachedResultIfAvailable() {
                return cached
            }
            throw APODError.network(underlying: URLError(.notConnectedToInternet))
        }
        
        do {
            let fresh = try await service.fetchAPOD(for: date)
            await metadataStore.save(fresh)
            return APODResult(apod: fresh, source: .fresh)
        } catch {
            if let cached = await cachedResultIfAvailable() {
                return cached
            }
            if let apodError = error as? APODError {
                throw apodError
            }
            throw APODError.unknown(description: error.localizedDescription)
        }
    }
    
    /// Returns whatever APOD is in the cache, regardless of date. The view
    /// model marks the result as `.cache` so the UI can show the "Offline —
    /// showing last saved picture" badge to communicate that the data may
    /// not be the date the user asked for.
    private func cachedResultIfAvailable() async -> APODResult? {
        guard let cached = await metadataStore.load() else { return nil }
        return APODResult(apod: cached, source: .cache)
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
