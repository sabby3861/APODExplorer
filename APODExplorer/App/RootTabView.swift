//
//  RootTabView.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 21/04/2026.
//

import SwiftUI

struct RootTabView: View {
    let dependencies: AppDependencies
    
    @State private var todayViewModel: TodayViewModel
    
    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._todayViewModel = State(
            initialValue: TodayViewModel(repository: dependencies.repository)
        )
    }
    
    var body: some View {
        TabView {
            Tab("Today", systemImage: "photo.on.rectangle.angled") {
                TodayView(
                    viewModel: todayViewModel,
                    mediaLoader: dependencies.repository
                )
            }
            
            Tab("Browse", systemImage: "calendar") {
                BrowseView()
            }
        }
    }
}

#Preview {
    RootTabView(dependencies: AppDependencies(repository: PreviewMocks.previewRepository))
}
