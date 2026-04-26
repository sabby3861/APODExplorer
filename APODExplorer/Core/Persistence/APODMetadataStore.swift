//
//  APODMetadataStore.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 22/04/2026.
//
//  Persists the most recent APOD response for offline fallback. Single JSON
//  file in the caches directory — no database, since we are only keeping one entry.
//

import Foundation

protocol APODMetadataStore: Sendable {
    func load() async -> APOD?
    func save(_ apod: APOD) async
    func clear() async
}

actor DefaultAPODMetadataStore: APODMetadataStore {
    private let fileURL: URL
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        let baseDirectory = directory ?? Self.appSupportDirectory(fileManager: fileManager)
        let storeDirectory = baseDirectory.appendingPathComponent("APODStore", isDirectory: true)
        if !fileManager.fileExists(atPath: storeDirectory.path) {
            try? fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        }
        self.fileURL = storeDirectory.appendingPathComponent("latest.json")
    }
    
    private static func appSupportDirectory(fileManager: FileManager) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? fileManager.temporaryDirectory
    }
    
    func load() async -> APOD? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(APOD.self, from: data)
    }
    
    func save(_ apod: APOD) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(apod) else { return }
        // Atomic write — we don't want a half-written file if the app is
        // killed mid-save.
        try? data.write(to: fileURL, options: .atomic)
    }
    
    func clear() async {
        try? fileManager.removeItem(at: fileURL)
    }
}
