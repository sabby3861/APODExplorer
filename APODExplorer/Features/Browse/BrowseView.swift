//
//  BrowseView.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 26/04/2026.
//
//  Keeping stubbed second tab. The brief mentions a Tab Bar will "help when later
//  you are asked to expand," so this is where that expansion lands —
//  likely browse-by-range, favorites, or search.
//

import SwiftUI

struct BrowseView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "calendar")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                
                Text("Browse")
                    .font(.title.weight(.semibold))
                
                Text("Browse historical APODs, save favorites, and explore NASA's archive — coming in a future release.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Browse tab. Coming in a future release.")
        }
    }
}

#Preview {
    BrowseView()
}
