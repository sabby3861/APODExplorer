//
//  TodayViewModel.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 24/04/2026.
//
//  State holder for the Today tab. State is modelled as an enum so
//  impossible combinations (e.g. loading+loaded) can't exist.
//

import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded(APODResult)
        case failed(APODError)
    }
    
    private(set) var state: ViewState = .idle
    var selectedDate: APODDate
    var isShowingDatePicker: Bool = false
    
    private let repository: APODRepository
    
    init(repository: APODRepository, initialDate: APODDate = .today()) {
        self.repository = repository
        self.selectedDate = initialDate
    }
    
    // Only fetches on first appearance. Subsequent tab-switches don't refetch;
    // pull-to-refresh covers the "force reload" case.
    func onAppear() async {
        if case .idle = state {
            await loadAPOD(for: selectedDate)
        }
    }
    
    func refresh() async {
        await loadAPOD(for: selectedDate)
    }
    
    func selectDate(_ date: APODDate) async {
        guard date != selectedDate else { return }
        selectedDate = date
        await loadAPOD(for: date)
    }
    
    private func loadAPOD(for date: APODDate) async {
        state = .loading
        do {
            let result = try await repository.fetchAPOD(for: date)
            state = .loaded(result)
        } catch let error as APODError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown(description: error.localizedDescription))
        }
    }
}

