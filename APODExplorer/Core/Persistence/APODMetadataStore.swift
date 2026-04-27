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
    /// Returns the cached APOD for an exact date, or nil if not cached.
    func load(for date: APODDate) async -> APOD?

    /// Returns the most recently saved APOD across all dates, or nil if
    /// the store is empty.
    func loadLatest() async -> APOD?

    func save(_ apod: APOD) async
    func clear() async
}

actor DefaultAPODMetadataStore: APODMetadataStore {
    private let directory: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        let baseDirectory = directory ?? Self.appSupportDirectory(fileManager: fileManager)
        let storeDirectory = baseDirectory.appendingPathComponent("APODStore", isDirectory: true)
        if !fileManager.fileExists(atPath: storeDirectory.path) {
            try? fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        }
        self.directory = storeDirectory
    }

    /// Application Support is durable across launches — iOS won't purge it.
    private static func appSupportDirectory(fileManager: FileManager) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
    }

    func load(for date: APODDate) async -> APOD? {
        let fileURL = directory.appendingPathComponent("\(date.apiString).json")
        return decode(at: fileURL)
    }

    func loadLatest() async -> APOD? {
        let pointer = directory.appendingPathComponent("latest.txt")
        guard
            let dateString = try? String(contentsOf: pointer, encoding: .utf8),
            !dateString.isEmpty
        else { return nil }
        let fileURL = directory.appendingPathComponent("\(dateString).json")
        return decode(at: fileURL)
    }

    func save(_ apod: APOD) async {
        guard
            let apodDate = APODDate(date: apod.date),
            let payload = encode(apod)
        else { return }

        let fileURL = directory.appendingPathComponent("\(apodDate.apiString).json")
        // Atomic write — no half-written files if the app is killed mid-save.
        try? payload.write(to: fileURL, options: .atomic)

        // Track this as the most-recently-saved date for the fallback case.
        let pointer = directory.appendingPathComponent("latest.txt")
        try? Data(apodDate.apiString.utf8).write(to: pointer, options: .atomic)
    }

    func clear() async {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for fileURL in contents {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Helpers

    private func decode(at fileURL: URL) -> APOD? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(APOD.self, from: data)
    }

    private func encode(_ apod: APOD) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(apod)
    }
}
