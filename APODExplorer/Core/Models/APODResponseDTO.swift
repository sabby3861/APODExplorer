//
//  APODResponseDTO.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 21/04/2026.
//
//  Wire format for NASA's APOD endpoint. Kept separate from `APOD` because
//  NASA returns `date` as a string; this is where we parse it.
//

import Foundation

struct APODResponseDTO: Decodable {
    let date: String
    let title: String
    let explanation: String
    let mediaType: String
    let url: String
    let hdurl: String?
    let copyright: String?
    
    enum CodingKeys: String, CodingKey {
        case date, title, explanation, url, hdurl, copyright
        case mediaType = "media_type"
    }
}

extension APODResponseDTO {
    func toDomain() throws -> APOD {
        guard let parsedDate = Self.apiDateFormatter.date(from: date) else {
            throw APODError.decoding(description: "Invalid date format: \(date)")
        }
        
        guard let resolvedMediaType = APOD.MediaType(rawValue: mediaType) else {
            throw APODError.decoding(description: "Unexpected media_type: \(mediaType)")
        }
        
        guard let mediaURL = URL(string: url) else {
            throw APODError.decoding(description: "Invalid URL: \(url)")
        }
        
        return APOD(
            date: parsedDate,
            title: Self.normalizeWhitespace(title),
            explanation: Self.normalizeWhitespace(explanation),
            mediaType: resolvedMediaType,
            url: mediaURL,
            hdURL: hdurl.flatMap(URL.init(string:)),
            copyright: copyright?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    /// NASA's APOD writers use double-spaces between sentences (an old
    /// typewriter convention); modern iOS rendering looks better with single
    /// spaces.
    private static func normalizeWhitespace(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
    }
    
    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .posixGMT
        formatter.timeZone = .gmt
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
