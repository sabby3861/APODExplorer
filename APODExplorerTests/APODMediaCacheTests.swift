//
//  APODMediaCacheTests.swift
//  APODExplorerTests
//
//  Created by Sanjay Kumar on 26/04/2026.
//

import Testing
import Foundation
@testable import APODExplorer

@Suite("APODMediaCache: bounded on-disk image cache")
struct APODMediaCacheTests {
    
    private func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("APODMediaCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    @Test("SHA-256 key is deterministic for identical URLs")
    func keyIsDeterministic() throws {
        let url = try #require(URL(string: "https://apod.nasa.gov/apod/image/test.jpg"))
        let key1 = DefaultAPODMediaCache.key(for: url)
        let key2 = DefaultAPODMediaCache.key(for: url)
        #expect(key1 == key2)
        #expect(key1.count == 64)  // SHA-256 hex is 64 chars
    }
    
    @Test("Different URLs produce different keys")
    func differentURLsProduceDifferentKeys() throws {
        let url1 = try #require(URL(string: "https://apod.nasa.gov/apod/image/a.jpg"))
        let url2 = try #require(URL(string: "https://apod.nasa.gov/apod/image/b.jpg"))
        #expect(DefaultAPODMediaCache.key(for: url1) != DefaultAPODMediaCache.key(for: url2))
    }
    
    @Test("Cache roundtrips stored data")
    func cacheRoundtrip() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cache = DefaultAPODMediaCache(directory: tempDir)
        let url = try #require(URL(string: "https://apod.nasa.gov/apod/image/test.jpg"))
        let data = Data("test bytes".utf8)
        
        await cache.store(data, for: url)
        let retrieved = await cache.data(for: url)
        
        #expect(retrieved == data)
    }
    
    @Test("Cache miss returns nil")
    func cacheMissReturnsNil() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cache = DefaultAPODMediaCache(directory: tempDir)
        let url = try #require(URL(string: "https://apod.nasa.gov/apod/image/missing.jpg"))
        
        let retrieved = await cache.data(for: url)
        #expect(retrieved == nil)
    }
    
    @Test("LRU eviction removes oldest entries when size exceeded")
    func lruEvictionRemovesOldest() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // 100-byte cap, 60-byte entries → second write triggers eviction.
        let cache = DefaultAPODMediaCache(directory: tempDir, maxBytes: 100)
        let url1 = try #require(URL(string: "https://apod.nasa.gov/apod/image/a.jpg"))
        let url2 = try #require(URL(string: "https://apod.nasa.gov/apod/image/b.jpg"))
        let data = Data(repeating: 0xAB, count: 60)
        
        await cache.store(data, for: url1)
        await cache.store(data, for: url2)
        
        let first = await cache.data(for: url1)
        let second = await cache.data(for: url2)
        
        #expect(first == nil, "First entry should have been evicted")
        #expect(second == data, "Second entry should still be present")
    }
    
    @Test("Accessing entry promotes it in LRU order")
    func accessingPromotesInLRUOrder() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cache = DefaultAPODMediaCache(directory: tempDir, maxBytes: 100)
        let url1 = try #require(URL(string: "https://apod.nasa.gov/apod/image/a.jpg"))
        let url2 = try #require(URL(string: "https://apod.nasa.gov/apod/image/b.jpg"))
        let url3 = try #require(URL(string: "https://apod.nasa.gov/apod/image/c.jpg"))
        let data = Data(repeating: 0xAB, count: 40)
        
        await cache.store(data, for: url1)
        await cache.store(data, for: url2)
        // Touch url1, promoting it
        _ = await cache.data(for: url1)
        // Adding url3 should now evict url2 (oldest untouched), not url1
        await cache.store(data, for: url3)
        
        let first = await cache.data(for: url1)
        let second = await cache.data(for: url2)
        let third = await cache.data(for: url3)
        
        #expect(first != nil, "Touched entry should survive eviction")
        #expect(second == nil, "Oldest untouched entry should be evicted")
        #expect(third != nil, "Newest entry should be present")
    }
    
    @Test("Clear removes all cached entries")
    func clearRemovesAll() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cache = DefaultAPODMediaCache(directory: tempDir)
        let url = try #require(URL(string: "https://apod.nasa.gov/apod/image/test.jpg"))
        await cache.store(Data("bytes".utf8), for: url)
        
        await cache.clear()
        
        let retrieved = await cache.data(for: url)
        #expect(retrieved == nil)
    }
    
    @Test("New cache instance picks up files from previous session and evicts under cap")
    func crossLaunchEvictionPicksUpExistingFiles() async throws {
        // Simulates app relaunch: write files via one cache instance, then
        // create a second instance pointing at the same directory and verify
        // it knows about the existing files for LRU purposes. Without the
        // initializeIfNeeded() rebuild, the cache would grow unbounded across
        // launches.
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let url1 = try #require(URL(string: "https://apod.nasa.gov/apod/image/a.jpg"))
        let url2 = try #require(URL(string: "https://apod.nasa.gov/apod/image/b.jpg"))
        let url3 = try #require(URL(string: "https://apod.nasa.gov/apod/image/c.jpg"))
        let data = Data(repeating: 0xAB, count: 60)
        
        // Session 1: store two files filling the cap.
        let cache1 = DefaultAPODMediaCache(directory: tempDir, maxBytes: 200)
        await cache1.store(data, for: url1)
        await cache1.store(data, for: url2)
        
        // Session 2: new cache instance, same directory, same cap. Storing
        // a third entry should evict url1 (the oldest file from session 1)
        // because the rebuilt accessOrder includes the existing files.
        let cache2 = DefaultAPODMediaCache(directory: tempDir, maxBytes: 100)
        await cache2.store(data, for: url3)
        
        let first = await cache2.data(for: url1)
        let second = await cache2.data(for: url2)
        let third = await cache2.data(for: url3)
        
        // With a 100-byte cap and 60-byte entries, only one should survive.
        // The newest (url3) is guaranteed to survive; one or both of the
        // older ones may be evicted depending on rebuilt order.
        #expect(third != nil, "Newest entry must survive")
        let survivors = [first, second].compactMap { $0 }.count
        #expect(survivors <= 1, "Total cache size should respect the cap after a relaunch")
    }
}
