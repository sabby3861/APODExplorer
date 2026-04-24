//
//  APODError.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 21/04/2026.
//
//  Typed errors for everything that throws in this app. The view layer
//  reads `userMessage`; logs read the associated values.
//

import Foundation

enum APODError: Error, Equatable, Sendable {
    case invalidDate(reason: String)
    case network(underlying: URLError)
    case decoding(description: String)
    case serverError(status: Int)
    case noCachedData
    case unknown(description: String)
    
    static func == (lhs: APODError, rhs: APODError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidDate(let l), .invalidDate(let r)): return l == r
        case (.network(let l), .network(let r)): return l.code == r.code
        case (.decoding(let l), .decoding(let r)): return l == r
        case (.serverError(let l), .serverError(let r)): return l == r
        case (.noCachedData, .noCachedData): return true
        case (.unknown(let l), .unknown(let r)): return l == r
        default: return false
        }
    }
}

extension APODError {
    var userMessage: String {
        switch self {
        case .invalidDate(let reason):
            return reason
        case .network:
            return "Couldn't reach NASA. Check your connection and try again."
        case .decoding, .unknown:
            return "Something went wrong. Please try again."
        case .serverError:
            return "NASA's server is having a moment. Please try again shortly."
        case .noCachedData:
            return "No saved picture available yet. Connect to the internet to load today's picture."
        }
    }
}
