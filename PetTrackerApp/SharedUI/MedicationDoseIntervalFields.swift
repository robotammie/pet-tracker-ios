import SwiftUI

struct MedicationDoseIntervalFields: View {
    @Binding var minimumHours: Double
    @Binding var maximumHours: Double
    var accessibilityPrefix = "medicineTiming"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Minimum hours between doses")
            TextField("Minimum hours", value: $minimumHours, format: .number)
                .keyboardType(.decimalPad)
                .frame(minHeight: 44)
                .accessibilityLabel("Minimum hours between doses")
                .accessibilityIdentifier("\(accessibilityPrefix).minimumHours")
            Text("Maximum hours in prescribed window")
            TextField("Maximum hours", value: $maximumHours, format: .number)
                .keyboardType(.decimalPad)
                .frame(minHeight: 44)
                .accessibilityLabel("Maximum hours in prescribed window")
                .accessibilityIdentifier("\(accessibilityPrefix).maximumHours")
        }
    }
}
