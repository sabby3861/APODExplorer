//
//  APODService.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 24/04/2026.
//
//  NASA APOD endpoint. Builds the request, decodes the response.
//

import Foundation

protocol APODService: Sendable {
    func fetchAPOD(for date: APODDate) async throws -> APOD
}

struct DefaultAPODService: APODService {
    static let defaultBaseURL: URL = {
        guard let url = URL(string: "https://api.nasa.gov/planetary/apod") else {
            preconditionFailure("Default NASA APOD URL literal is invalid")
        }
        return url
    }()
    
    private let networkClient: NetworkClient
    private let apiKey: String
    private let baseURL: URL
    
    init(
        networkClient: NetworkClient,
        apiKey: String = "uKfIgQoOHke3jcuokrv0NWbvYAYDldsqjkCw5z1b",
        baseURL: URL = DefaultAPODService.defaultBaseURL
    ) {
        self.networkClient = networkClient
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func fetchAPOD(for date: APODDate) async throws -> APOD {
        let request = try makeRequest(for: date)
        let (data, response) = try await networkClient.data(for: request)
        
        guard (200..<300).contains(response.statusCode) else {
            throw APODError.serverError(status: response.statusCode)
        }
        
        do {
            let dto = try JSONDecoder().decode(APODResponseDTO.self, from: data)
            return try dto.toDomain()
        } catch let error as APODError {
            throw error
        } catch {
            throw APODError.decoding(description: error.localizedDescription)
        }
    }
    
    private func makeRequest(for date: APODDate) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APODError.unknown(description: "Could not parse base URL")
        }
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "date", value: date.apiString),
            URLQueryItem(name: "thumbs", value: "true")
        ]
        guard let url = components.url else {
            throw APODError.unknown(description: "Could not construct URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        return request
    }
}
