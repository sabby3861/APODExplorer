//
//  AppDependencies.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 24/04/2026.
//
//  Composition root. The only place that knows about concrete implementations.
//  Everything else consumes protocols.
//

import Foundation

@MainActor
final class AppDependencies {
    let repository: APODRepository
    
    init() {
        let networkClient = URLSessionNetworkClient()
        let service = DefaultAPODService(networkClient: networkClient)
        let metadataStore = DefaultAPODMetadataStore()
        let mediaCache = DefaultAPODMediaCache()
        let networkMonitor = DefaultNetworkMonitor()
        
        self.repository = DefaultAPODRepository(
            service: service,
            networkClient: networkClient,
            metadataStore: metadataStore,
            mediaCache: mediaCache,
            networkMonitor: networkMonitor
        )
    }
    
    // For tests and previews.
    init(repository: APODRepository) {
        self.repository = repository
    }
}
