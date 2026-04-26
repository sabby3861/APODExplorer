//
//  APODExplorerApp.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 21/04/2026.
//

import SwiftUI

@main
struct APODExplorerApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
    }
}
