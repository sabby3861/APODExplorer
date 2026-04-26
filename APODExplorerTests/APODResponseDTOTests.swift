//
//  APODResponseDTOTests.swift
//  APODExplorerTests
//
//  Created by Sanjay Kumar on 26/04/2026.
//

import Testing
import Foundation
@testable import APODExplorer

@Suite("APODResponseDTO: wire format decoding and domain mapping")
struct APODResponseDTOTests {
    
    @Test("Decodes standard image APOD response")
    func decodesImageResponse() throws {
        let dto = try JSONDecoder().decode(APODResponseDTO.self, from: APODFixture.sampleJSON)
        
        #expect(dto.date == "2024-01-15")
        #expect(dto.title == "Galaxy Cluster")
        #expect(dto.mediaType == "image")
        #expect(dto.hdurl != nil)
        #expect(dto.copyright == "NASA")
    }
    
    @Test("Decodes video APOD response with missing hdurl")
    func decodesVideoResponse() throws {
        let dto = try JSONDecoder().decode(APODResponseDTO.self, from: APODFixture.videoJSON)
        
        #expect(dto.mediaType == "video")
        #expect(dto.hdurl == nil)
        #expect(dto.copyright == nil)
    }
    
    @Test("Maps valid DTO to domain model")
    func mapsValidDTOToDomain() throws {
        let dto = try JSONDecoder().decode(APODResponseDTO.self, from: APODFixture.sampleJSON)
        let apod = try dto.toDomain()
        
        #expect(apod.title == "Galaxy Cluster")
        #expect(apod.mediaType == .image)
        #expect(apod.hdURL != nil)
    }
    
    @Test("Rejects unexpected media_type values")
    func rejectsUnexpectedMediaType() throws {
        let badJSON = Data("""
        {
            "date": "2024-01-15",
            "title": "X",
            "explanation": "Y",
            "media_type": "interactive",
            "url": "https://example.com/x.html"
        }
        """.utf8)
        
        let dto = try JSONDecoder().decode(APODResponseDTO.self, from: badJSON)
        
        #expect(throws: APODError.self) {
            _ = try dto.toDomain()
        }
    }
    
    @Test("Rejects malformed date strings")
    func rejectsMalformedDate() throws {
        let badJSON = Data("""
        {
            "date": "15-01-2024",
            "title": "X",
            "explanation": "Y",
            "media_type": "image",
            "url": "https://example.com/x.jpg"
        }
        """.utf8)
        
        let dto = try JSONDecoder().decode(APODResponseDTO.self, from: badJSON)
        
        #expect(throws: APODError.self) {
            _ = try dto.toDomain()
        }
    }
    
    @Test("Preferred media URL prefers hdurl for images")
    func preferredURLPrefersHDForImages() throws {
        let apod = APODFixture.image()
        let hdURL = try #require(apod.hdURL)
        #expect(apod.preferredMediaURL == hdURL)
    }
    
    @Test("Preferred media URL falls back to url when hdurl is nil")
    func preferredURLFallsBack() throws {
        let url = try #require(URL(string: "https://example.com/x.jpg"))
        let apod = APOD(
            date: Date(),
            title: "X",
            explanation: "Y",
            mediaType: .image,
            url: url,
            hdURL: nil,
            copyright: nil
        )
        #expect(apod.preferredMediaURL == apod.url)
    }
    
    @Test("Preferred media URL uses url for videos regardless of hdurl")
    func preferredURLUsesURLForVideos() {
        let apod = APODFixture.video()
        #expect(apod.preferredMediaURL == apod.url)
    }
    
    @Test("Whitespace in title and explanation is normalized")
    func whitespaceIsNormalized() throws {
        // NASA returns double-spaces between sentences and occasionally
        // mid-sentence; the mapper should collapse them.
        let messyJSON = Data("""
        {
            "date": "2024-01-15",
            "title": "  Galaxy   Cluster  ",
            "explanation": "First sentence.  Second sentence.  Mid  sentence  spaces.",
            "media_type": "image",
            "url": "https://apod.nasa.gov/apod/image/x.jpg"
        }
        """.utf8)
        
        let dto = try JSONDecoder().decode(APODResponseDTO.self, from: messyJSON)
        let apod = try dto.toDomain()
        
        #expect(apod.title == "Galaxy Cluster")
        #expect(apod.explanation == "First sentence. Second sentence. Mid sentence spaces.")
    }
}
