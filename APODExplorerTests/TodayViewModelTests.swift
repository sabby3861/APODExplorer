//
//  TodayViewModelTests.swift
//  APODExplorerTests
//
//  Created by Sanjay Kumar on 26/04/2026.
//
//  State machine tests. Uses a stub repository, not the real one — the view
//  model just orchestrates transitions; SWR is tested separately.
//

import Testing
import Foundation
@testable import APODExplorer

final class StubRepository: APODRepository, @unchecked Sendable {
    var stubbedAPOD: Result<APODResult, Error>?
    var stubbedMedia: Result<Data, Error>?
    var fetchCount = 0
    
    func fetchAPOD(for date: APODDate) async throws -> APODResult {
        fetchCount += 1
        switch stubbedAPOD {
        case .success(let result): return result
        case .failure(let error): throw error
        case .none: throw APODError.unknown(description: "Not configured")
        }
    }
    
    func fetchMedia(for apod: APOD) async throws -> Data {
        switch stubbedMedia {
        case .success(let data): return data
        case .failure(let error): throw error
        case .none: throw APODError.unknown(description: "Not configured")
        }
    }
}

@Suite("TodayViewModel: state machine")
@MainActor
struct TodayViewModelTests {
    
    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let viewModel = TodayViewModel(repository: StubRepository())
        #expect(viewModel.state == .idle)
    }
    
    @Test("onAppear transitions idle → loaded on success")
    func onAppearTransitionsToLoaded() async {
        let repository = StubRepository()
        let fixture = APODFixture.image()
        repository.stubbedAPOD = .success(APODResult(apod: fixture, source: .fresh))
        
        let viewModel = TodayViewModel(repository: repository)
        await viewModel.onAppear()
        
        guard case .loaded(let result) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(result.apod == fixture)
    }
    
    @Test("onAppear transitions idle → failed on error")
    func onAppearTransitionsToFailed() async {
        let repository = StubRepository()
        repository.stubbedAPOD = .failure(APODError.network(underlying: URLError(.timedOut)))
        
        let viewModel = TodayViewModel(repository: repository)
        await viewModel.onAppear()
        
        guard case .failed = viewModel.state else {
            Issue.record("Expected .failed state, got \(viewModel.state)")
            return
        }
    }
    
    @Test("onAppear does not refetch if already loaded")
    func onAppearSkipsIfAlreadyLoaded() async {
        let repository = StubRepository()
        repository.stubbedAPOD = .success(APODResult(apod: APODFixture.image(), source: .fresh))
        
        let viewModel = TodayViewModel(repository: repository)
        await viewModel.onAppear()
        await viewModel.onAppear()
        
        #expect(repository.fetchCount == 1)
    }
    
    @Test("Refresh always triggers a new fetch")
    func refreshTriggersFetch() async {
        let repository = StubRepository()
        repository.stubbedAPOD = .success(APODResult(apod: APODFixture.image(), source: .fresh))
        
        let viewModel = TodayViewModel(repository: repository)
        await viewModel.onAppear()
        await viewModel.refresh()
        await viewModel.refresh()
        
        #expect(repository.fetchCount == 3)
    }
    
    @Test("Selecting a new date triggers a fetch with that date")
    func selectDateTriggersFetch() async throws {
        let repository = StubRepository()
        let fixture = APODFixture.image()
        repository.stubbedAPOD = .success(APODResult(apod: fixture, source: .fresh))
        
        let viewModel = TodayViewModel(repository: repository)
        await viewModel.onAppear()
        
        let newDate = try #require(APODDate(date: Date(timeIntervalSince1970: 1_600_000_000)))
        await viewModel.selectDate(newDate)
        
        #expect(viewModel.selectedDate == newDate)
        #expect(repository.fetchCount == 2)
    }
    
    @Test("Selecting the same date does not trigger a fetch")
    func selectSameDateDoesNothing() async {
        let repository = StubRepository()
        repository.stubbedAPOD = .success(APODResult(apod: APODFixture.image(), source: .fresh))
        
        let viewModel = TodayViewModel(repository: repository)
        await viewModel.onAppear()
        
        let currentDate = viewModel.selectedDate
        await viewModel.selectDate(currentDate)
        
        #expect(repository.fetchCount == 1)
    }
    
    @Test("Retry from failed state transitions to loaded on success")
    func retryAfterFailureLoadsSuccessfully() async {
        // Real-world flow: first attempt fails (no network), user taps Retry,
        // network recovers, second attempt succeeds. This exercises the
        // .failed → .loading → .loaded path which isn't covered by the
        // single-state tests.
        let repository = StubRepository()
        repository.stubbedAPOD = .failure(APODError.network(underlying: URLError(.timedOut)))
        
        let viewModel = TodayViewModel(repository: repository)
        await viewModel.onAppear()
        
        guard case .failed = viewModel.state else {
            Issue.record("Expected .failed after first attempt, got \(viewModel.state)")
            return
        }
        
        // Second attempt: stub success and retry.
        let fixture = APODFixture.image()
        repository.stubbedAPOD = .success(APODResult(apod: fixture, source: .fresh))
        await viewModel.refresh()
        
        guard case .loaded(let result) = viewModel.state else {
            Issue.record("Expected .loaded after retry, got \(viewModel.state)")
            return
        }
        #expect(result.apod == fixture)
    }
}
