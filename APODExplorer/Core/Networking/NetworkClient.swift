//
//  NetworkClient.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 23/04/2026.
//
//  Thin seam over URLSession. Two methods because we make both API calls
//  (URLRequest with query params) and media downloads (plain URL). Having
//  both on the protocol means every network call funnels through one
//  injection point.
//

import Foundation

protocol NetworkClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func data(from url: URL) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionNetworkClient: NetworkClient {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await perform { try await self.session.data(for: request) }
    }
    
    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        try await perform { try await self.session.data(from: url) }
    }
    
    private func perform(
        _ operation: () async throws -> (Data, URLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await operation()
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APODError.unknown(description: "Non-HTTP response")
            }
            return (data, httpResponse)
        } catch let error as APODError {
            throw error
        } catch let error as URLError {
            throw APODError.network(underlying: error)
        } catch is CancellationError {
            throw APODError.unknown(description: "Cancelled")
        } catch {
            throw APODError.unknown(description: error.localizedDescription)
        }
    }
}
