//
//  TestDoubles.swift
//  APODExplorerTests
//
//  Created by Sanjay Kumar on 26/04/2026.
//
//  Hand-rolled mocks for the test suite.
//

import Foundation
@testable import APODExplorer

// MARK: - Mock Network Client

final class MockNetworkClient: NetworkClient, @unchecked Sendable {
    var stubbedDataForRequest: Result<(Data, HTTPURLResponse), Error>?
    var stubbedDataFromURL: Result<(Data, HTTPURLResponse), Error>?
    var capturedRequests: [URLRequest] = []
    var capturedURLs: [URL] = []
    
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(request)
        switch stubbedDataForRequest {
        case .success(let pair): return pair
        case .failure(let error): throw error
        case .none: throw APODError.unknown(description: "Mock not configured")
        }
    }
    
    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        capturedURLs.append(url)
        switch stubbedDataFromURL {
        case .success(let pair): return pair
        case .failure(let error): throw error
        case .none: throw APODError.unknown(description: "Mock not configured")
        }
    }
}

// MARK: - Mock APOD Service

final class MockAPODService: APODService, @unchecked Sendable {
    var stubbedResult: Result<APOD, Error>?
    var fetchCallCount = 0
    var capturedDates: [APODDate] = []
    
    func fetchAPOD(for date: APODDate) async throws -> APOD {
        fetchCallCount += 1
        capturedDates.append(date)
        switch stubbedResult {
        case .success(let apod): return apod
        case .failure(let error): throw error
        case .none: throw APODError.unknown(description: "Mock not configured")
        }
    }
}

// MARK: - Mock Network Monitor

actor MockNetworkMonitor: NetworkMonitor {
    private var reachable: Bool
    
    init(isReachable: Bool = true) {
        self.reachable = isReachable
    }
    
    func setReachable(_ value: Bool) { self.reachable = value }
    
    var isReachable: Bool { reachable }
}

// MARK: - Mock Metadata Store

actor MockMetadataStore: APODMetadataStore {
    private var stored: APOD?
    
    func setStored(_ apod: APOD?) { self.stored = apod }
    
    func load() async -> APOD? { stored }
    func save(_ apod: APOD) async { stored = apod }
    func clear() async { stored = nil }
}

// MARK: - Mock Media Cache

actor MockMediaCache: APODMediaCache {
    private var storage: [URL: Data] = [:]
    
    func data(for url: URL) async -> Data? { storage[url] }
    func store(_ data: Data, for url: URL) async { storage[url] = data }
    func clear() async { storage.removeAll() }
}

// MARK: - Fixtures

enum APODFixture {
    /// Test URLs with guaranteed-valid literals. A `preconditionFailure`
    /// fallback documents the invariant rather than force-unwrapping.
    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Test URL literal is invalid: \(string)")
        }
        return url
    }
    
    static func image(date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> APOD {
        APOD(
            date: date,
            title: "Test Image",
            explanation: "An explanation.",
            mediaType: .image,
            url: url("https://apod.nasa.gov/apod/image/test.jpg"),
            hdURL: url("https://apod.nasa.gov/apod/image/test_hd.jpg"),
            copyright: nil
        )
    }
    
    static func video(date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> APOD {
        APOD(
            date: date,
            title: "Test Video",
            explanation: "A video explanation.",
            mediaType: .video,
            url: url("https://www.youtube.com/embed/abc123"),
            hdURL: nil,
            copyright: nil
        )
    }
    
    static let sampleJSON: Data = Data("""
    {
        "date": "2024-01-15",
        "title": "Galaxy Cluster",
        "explanation": "A stunning view.",
        "media_type": "image",
        "url": "https://apod.nasa.gov/apod/image/2401/galaxy.jpg",
        "hdurl": "https://apod.nasa.gov/apod/image/2401/galaxy_hd.jpg",
        "copyright": "NASA"
    }
    """.utf8)
    
    static let videoJSON: Data = Data("""
    {
        "date": "2021-10-11",
        "title": "Perseverance Landing",
        "explanation": "Mars descent.",
        "media_type": "video",
        "url": "https://www.youtube.com/embed/4czjS9h4Fpg"
    }
    """.utf8)
}
