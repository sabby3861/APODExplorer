//
//  NetworkMonitor.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 23/04/2026.
//
//  Wraps NWPathMonitor to give the repository a fast offline check. Used to
//  short-circuit to cache instead of waiting for a 15-second URLSession
//  timeout when we already know we're offline.
//

import Foundation
import Network

protocol NetworkMonitor: Sendable {
    /// Best-effort current reachability. May lag real state by a few ms
    /// around transitions; callers shouldn't treat it as authoritative.
    var isReachable: Bool { get async }
}

actor DefaultNetworkMonitor: NetworkMonitor {
    private let monitor: NWPathMonitor
    private var currentStatus: NWPath.Status = .satisfied
    
    init() {
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { await self.updateStatus(path.status) }
        }
        let queue = DispatchQueue(label: "APODExplorer.NetworkMonitor")
        self.monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    var isReachable: Bool {
        currentStatus == .satisfied
    }
    
    private func updateStatus(_ status: NWPath.Status) {
        currentStatus = status
    }
}
