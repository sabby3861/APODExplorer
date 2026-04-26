//
//  TodayView.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 26/04/2026.
//

import SwiftUI

struct TodayView: View {
    @Bindable var viewModel: TodayViewModel
    let mediaLoader: MediaLoading

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Today")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbar }
                .task { await viewModel.onAppear() }
                .refreshable { await viewModel.refresh() }
                .onChange(of: scenePhase) { _, newPhase in
                    // Refresh when the app returns to the foreground if we're
                    // sitting on a stale error state. Loaded content stays put
                    // until the user explicitly pulls to refresh.
                    if newPhase == .active, case .failed = viewModel.state {
                        Task { await viewModel.refresh() }
                    }
                }
                .sheet(isPresented: $viewModel.isShowingDatePicker) {
                    DatePickerSheet(
                        selectedDate: viewModel.selectedDate,
                        onSelect: { newDate in
                            viewModel.isShowingDatePicker = false
                            Task { await viewModel.selectDate(newDate) }
                        },
                        onCancel: {
                            viewModel.isShowingDatePicker = false
                        }
                    )
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .loaded(let result):
            LoadedView(result: result, mediaLoader: mediaLoader)
        case .failed(let error):
            ErrorView(error: error) {
                Task { await viewModel.refresh() }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.isShowingDatePicker = true
            } label: {
                Image(systemName: "calendar")
            }
            .accessibilityLabel("Choose date")
            .accessibilityHint("Opens date picker to browse APOD for any day")
        }
    }
}

// MARK: - Loaded

private struct LoadedView: View {
    let result: APODResult
    let mediaLoader: MediaLoading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if result.source == .cache {
                    OfflineBadge()
                }

                MediaView(apod: result.apod, mediaLoader: mediaLoader)

                VStack(alignment: .leading, spacing: 8) {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Date: \(accessibleDate)")

                    Text(result.apod.title)
                        .font(.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    if let copyright = result.apod.copyright {
                        Text("© \(copyright)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(result.apod.explanation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 4)
            }
            .padding()
        }
    }

    // The APOD's date represents NASA's calendar day in GMT. We read it in
    // GMT so users west of UTC don't see yesterday's label for today's APOD.
    // `Date.FormatStyle` (iOS 15+) is the modern, cached, locale-aware API —
    // cheaper than constructing a DateFormatter per body evaluation.
    private var formattedDate: String {
        result.apod.date.formatted(
            Date.FormatStyle(date: .long, time: .omitted, timeZone: .gmt)
        )
    }

    private var accessibleDate: String {
        result.apod.date.formatted(
            Date.FormatStyle(date: .complete, time: .omitted, timeZone: .gmt)
        )
    }
}

// MARK: - Loading

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Loading today's picture")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Error

private struct ErrorView: View {
    let error: APODError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(error.userMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint("Retries loading the picture")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Offline Badge

private struct OfflineBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing last saved picture")
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(Color.orange)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Loaded — Image") {
    TodayView(
        viewModel: PreviewMocks.loadedImageViewModel(),
        mediaLoader: PreviewMocks.imageLoader
    )
}

#Preview("Loaded — Video") {
    TodayView(
        viewModel: PreviewMocks.loadedVideoViewModel(),
        mediaLoader: PreviewMocks.imageLoader
    )
}

#Preview("Loading") {
    TodayView(
        viewModel: PreviewMocks.loadingViewModel(),
        mediaLoader: PreviewMocks.imageLoader
    )
}

#Preview("Error") {
    TodayView(
        viewModel: PreviewMocks.failedViewModel(),
        mediaLoader: PreviewMocks.imageLoader
    )
}

#Preview("Offline (cached)") {
    TodayView(
        viewModel: PreviewMocks.cachedViewModel(),
        mediaLoader: PreviewMocks.imageLoader
    )
}

#Preview("Dark Mode") {
    TodayView(
        viewModel: PreviewMocks.loadedImageViewModel(),
        mediaLoader: PreviewMocks.imageLoader
    )
    .preferredColorScheme(.dark)
}

#Preview("Dynamic Type — XXXL") {
    TodayView(
        viewModel: PreviewMocks.loadedImageViewModel(),
        mediaLoader: PreviewMocks.imageLoader
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}

