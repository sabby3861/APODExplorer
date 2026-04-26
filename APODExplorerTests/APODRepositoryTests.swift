//
//  APODRepositoryTests.swift
//  APODExplorerTests
//
//  Created by Sanjay Kumar on 26/04/2026.
//
//  Tests the single most important behaviour in the app: "Last service call
//  including image should be cached and loaded if any subsequent service call
//  fails." (JPMC brief, verbatim.)
//

import Testing
import Foundation
@testable import APODExplorer

@Suite("APODRepository: offline fallback semantics")
struct APODRepositoryTests {
    
    private func makeRepository(
        service: APODService,
        metadataStore: APODMetadataStore,
        networkClient: NetworkClient = MockNetworkClient(),
        mediaCache: APODMediaCache = MockMediaCache(),
        networkMonitor: NetworkMonitor = MockNetworkMonitor(isReachable: true)
    ) -> APODRepository {
        DefaultAPODRepository(
            service: service,
            networkClient: networkClient,
            metadataStore: metadataStore,
            mediaCache: mediaCache,
            networkMonitor: networkMonitor
        )
    }
    
    @Test("Fresh network success returns fresh result and saves to cache")
    func freshNetworkSuccessSavesAndReturns() async throws {
        let service = MockAPODService()
        let fixture = APODFixture.image()
        service.stubbedResult = .success(fixture)
        
        let store = MockMetadataStore()
        let repository = makeRepository(service: service, metadataStore: store)
        
        let date = try #require(APODDate(date: fixture.date))
        let result = try await repository.fetchAPOD(for: date)
        
        #expect(result.source == .fresh)
        #expect(result.apod == fixture)
        #expect(service.capturedDates == [date], "Repository should request the date the caller asked for")
        
        let persisted = await store.load()
        #expect(persisted == fixture)
    }
    
    @Test("Network failure with matching cached date returns cache")
    func networkFailureReturnsCacheWhenDatesMatch() async throws {
        let fixture = APODFixture.image()
        let service = MockAPODService()
        service.stubbedResult = .failure(APODError.network(underlying: URLError(.notConnectedToInternet)))
        
        let store = MockMetadataStore()
        await store.setStored(fixture)
        let repository = makeRepository(service: service, metadataStore: store)
        
        let date = try #require(APODDate(date: fixture.date))
        let result = try await repository.fetchAPOD(for: date)
        
        #expect(result.source == .cache)
        #expect(result.apod == fixture)
    }
    
    @Test("Network failure with mismatched cached date propagates error")
    func networkFailureWithMismatchedCachePropagates() async throws {
        // Cache holds an APOD from a different day than the one being
        // requested. Brief-compliant behaviour: don't serve the wrong
        // day's cache, which would mislead the user.
        let cachedFixture = APODFixture.image(date: Date(timeIntervalSince1970: 1_700_000_000))
        let service = MockAPODService()
        service.stubbedResult = .failure(APODError.network(underlying: URLError(.notConnectedToInternet)))
        
        let store = MockMetadataStore()
        await store.setStored(cachedFixture)
        let repository = makeRepository(service: service, metadataStore: store)
        
        let differentDate = try #require(APODDate(date: Date(timeIntervalSince1970: 1_600_000_000)))
        
        await #expect(throws: APODError.self) {
            _ = try await repository.fetchAPOD(for: differentDate)
        }
    }
    
    @Test("Network failure with empty cache propagates error")
    func networkFailureWithEmptyCachePropagates() async throws {
        let service = MockAPODService()
        service.stubbedResult = .failure(APODError.network(underlying: URLError(.timedOut)))
        
        let store = MockMetadataStore()
        let repository = makeRepository(service: service, metadataStore: store)
        
        let date = try #require(APODDate(date: Date(timeIntervalSince1970: 1_700_000_000)))
        
        await #expect(throws: APODError.self) {
            _ = try await repository.fetchAPOD(for: date)
        }
    }
    
    @Test("Fresh fetch overwrites previously cached entry")
    func freshFetchOverwritesCache() async throws {
        let oldFixture = APODFixture.image(date: Date(timeIntervalSince1970: 1_600_000_000))
        let newFixture = APODFixture.image(date: Date(timeIntervalSince1970: 1_700_000_000))
        
        let service = MockAPODService()
        service.stubbedResult = .success(newFixture)
        
        let store = MockMetadataStore()
        await store.setStored(oldFixture)
        let repository = makeRepository(service: service, metadataStore: store)
        
        let date = try #require(APODDate(date: newFixture.date))
        _ = try await repository.fetchAPOD(for: date)
        
        let persisted = await store.load()
        #expect(persisted == newFixture)
    }
    
    // MARK: - Media fetch
    
    @Test("Media cache hit returns bytes without network")
    func mediaCacheHitReturnsBytes() async throws {
        let fixture = APODFixture.image()
        let cachedData = Data("cached image".utf8)
        let cache = MockMediaCache()
        await cache.store(cachedData, for: fixture.preferredMediaURL)
        
        let networkClient = MockNetworkClient()
        // Stub the network call to fail. If the repository hits the network
        // (i.e. the cache check didn't short-circuit), the test fails because
        // fetchMedia would throw rather than return the cached bytes.
        networkClient.stubbedDataFromURL = .failure(APODError.unknown(description: "should not hit network"))
        
        let repository = makeRepository(
            service: MockAPODService(),
            metadataStore: MockMetadataStore(),
            networkClient: networkClient,
            mediaCache: cache
        )
        
        let data = try await repository.fetchMedia(for: fixture)
        #expect(data == cachedData)
        #expect(networkClient.capturedURLs.isEmpty, "Network should not be called on cache hit")
    }
    
    @Test("Media cache miss downloads and stores")
    func mediaCacheMissDownloads() async throws {
        let fixture = APODFixture.image()
        let downloadedData = Data("downloaded image".utf8)
        let response = try #require(HTTPURLResponse(
            url: fixture.preferredMediaURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        
        let networkClient = MockNetworkClient()
        networkClient.stubbedDataFromURL = .success((downloadedData, response))
        
        let cache = MockMediaCache()
        let repository = makeRepository(
            service: MockAPODService(),
            metadataStore: MockMetadataStore(),
            networkClient: networkClient,
            mediaCache: cache
        )
        
        let data = try await repository.fetchMedia(for: fixture)
        #expect(data == downloadedData)
        
        // Verify the cache now holds the downloaded data
        let cachedAfter = await cache.data(for: fixture.preferredMediaURL)
        #expect(cachedAfter == downloadedData)
    }
    
    // MARK: - Network monitor short-circuit
    
    @Test("Offline monitor short-circuits to cache without hitting network")
    func offlineServesCacheWithoutNetwork() async throws {
        let fixture = APODFixture.image()
        let service = MockAPODService()
        service.stubbedResult = .failure(APODError.unknown(description: "should not be called"))
        
        let store = MockMetadataStore()
        await store.setStored(fixture)
        
        let repository = makeRepository(
            service: service,
            metadataStore: store,
            networkMonitor: MockNetworkMonitor(isReachable: false)
        )
        
        let date = try #require(APODDate(date: fixture.date))
        let result = try await repository.fetchAPOD(for: date)
        
        #expect(result.source == .cache)
        #expect(service.fetchCallCount == 0, "Service should not be called when offline")
    }
    
    @Test("Offline with no matching cache throws network error")
    func offlineWithNoCacheThrows() async throws {
        let service = MockAPODService()
        let store = MockMetadataStore()
        
        let repository = makeRepository(
            service: service,
            metadataStore: store,
            networkMonitor: MockNetworkMonitor(isReachable: false)
        )
        
        let date = try #require(APODDate(date: Date(timeIntervalSince1970: 1_700_000_000)))
        
        await #expect(throws: APODError.self) {
            _ = try await repository.fetchAPOD(for: date)
        }
    }
    
    @Test("Offline with no cache throws specifically a `.network` error")
    func offlineWithNoCacheThrowsNetworkError() async throws {
        let service = MockAPODService()
        let store = MockMetadataStore()
        
        let repository = makeRepository(
            service: service,
            metadataStore: store,
            networkMonitor: MockNetworkMonitor(isReachable: false)
        )
        
        let date = try #require(APODDate(date: Date(timeIntervalSince1970: 1_700_000_000)))
        
        do {
            _ = try await repository.fetchAPOD(for: date)
            Issue.record("Expected fetchAPOD to throw")
        } catch let error as APODError {
            // Asserting on the specific case, not just the type.
            guard case .network = error else {
                Issue.record("Expected .network error, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected APODError, got \(type(of: error))")
        }
    }
}
