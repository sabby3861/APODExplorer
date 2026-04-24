//
//  APOD.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 21/04/2026.
//
//  Domain model representing an Astronomy Picture of the Day entry.
//
import Foundation

struct APOD: Equatable, Sendable, Codable {
    enum MediaType: String, Sendable, Codable {
        case image
        case video
    }

    let date: Date
    let title: String
    let explanation: String
    let mediaType: MediaType
    let url: URL
    let hdURL: URL?
    let copyright: String?
}

// MARK: - Convenience

extension APOD {
    /// The best URL to render for this entry. For images, prefers `hdurl` when
    /// available; for videos, always uses `url` since there is no HD variant.
    var preferredMediaURL: URL {
        mediaType == .image ? (hdURL ?? url) : url
    }
}
