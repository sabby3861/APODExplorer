//
//  APODMediaCache.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 22/04/2026.
//
//  Bounded disk cache for image bytes. SHA-256 of the URL as the filename,
//  LRU eviction once total size exceeds `maxBytes` (50 MB default).
//

import Foundation
import CryptoKit

protocol APODMediaCache: Sendable {
    func data(for url: URL) async -> Data?
    func store(_ data: Data, for url: URL) async
    func clear() async
}

actor DefaultAPODMediaCache: APODMediaCache {
    private let directory: URL
    private let fileManager: FileManager
    private let maxBytes: Int64
    private var accessOrder: [String] = []  // oldest at index 0, newest at end
    private var isInitialized = false
    
    init(
        fileManager: FileManager = .default,
        directory: URL? = nil,
        maxBytes: Int64 = 50 * 1024 * 1024
    ) {
        self.fileManager = fileManager
        self.maxBytes = maxBytes
        let baseDirectory = directory ?? Self.appSupportDirectory(fileManager: fileManager)
        self.directory = baseDirectory.appendingPathComponent("APODMedia", isDirectory: true)
        if !fileManager.fileExists(atPath: self.directory.path) {
            try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        }
    }
    
    private static func appSupportDirectory(fileManager: FileManager) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? fileManager.temporaryDirectory
    }
    
    /// Rebuild accessOrder from files on disk. Without this, files left over
    /// from a previous launch would be invisible to the LRU tracker and the
    /// cache would grow unbounded across sessions.
    private func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true
        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
        else { return }
        let sorted = contents.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }
        accessOrder = sorted.map { $0.lastPathComponent }
    }
    
    func data(for url: URL) async -> Data? {
        initializeIfNeeded()
        let key = Self.key(for: url)
        let fileURL = directory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        touch(key)
        return data
    }
    
    func store(_ data: Data, for url: URL) async {
        initializeIfNeeded()
        let key = Self.key(for: url)
        let fileURL = directory.appendingPathComponent(key)
        try? data.write(to: fileURL, options: .atomic)
        touch(key)
        evictIfNeeded()
    }
    
    func clear() async {
        initializeIfNeeded()
        accessOrder.removeAll()
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for fileURL in contents {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    private func touch(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    private func evictIfNeeded() {
        while currentSize > maxBytes, let oldest = accessOrder.first {
            let fileURL = directory.appendingPathComponent(oldest)
            try? fileManager.removeItem(at: fileURL)
            accessOrder.removeFirst()
        }
    }
    
    private var currentSize: Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }
    
    static func key(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
