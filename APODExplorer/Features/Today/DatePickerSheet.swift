//
//  DatePickerSheet.swift
//  APODExplorer
//
//  Created by Sanjay Kumar on 26/04/2026.
//
//  Sheet for picking an arbitrary APOD date. Range-bounded to the valid
//  APOD window so invalid dates aren't pickable.
//

import SwiftUI

struct DatePickerSheet: View {
    @State private var internalDate: Date
    let onSelect: (APODDate) -> Void
    let onCancel: () -> Void

    init(
        selectedDate: APODDate,
        onSelect: @escaping (APODDate) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._internalDate = State(initialValue: selectedDate.startOfDay)
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "APOD Date",
                    selection: $internalDate,
                    // End of today, not "now" — otherwise the user can't pick
                    // today if they open the sheet before local midnight when
                    // today is already valid per NASA's Eastern rollover.
                    in: APODDate.earliest...APODDate.today().startOfDay.addingTimeInterval(86_399),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()

                Spacer()
            }
            .navigationTitle("Choose a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .accessibilityHint("Dismisses the date picker without changing the date")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // localDate: preserves the user's intended calendar day.
                        // See APODDate for why.
                        if let apodDate = APODDate(localDate: internalDate) {
                            onSelect(apodDate)
                        } else {
                            onCancel()
                        }
                    }
                    .fontWeight(.semibold)
                    .accessibilityHint("Loads the picture for the selected date")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    DatePickerSheet(
        selectedDate: .today(),
        onSelect: { _ in },
        onCancel: { }
    )
}
