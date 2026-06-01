import SwiftUI

struct EventListView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var selectedType = CareEventType.food

    private var filteredEvents: [CareEvent] {
        store.events
            .filter { $0.type == selectedType }
            .sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        List {
            Picker("Event type", selection: $selectedType) {
                ForEach(CareEventType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Section(selectedType.rawValue) {
                if filteredEvents.isEmpty {
                    ContentUnavailableView("No events yet", systemImage: "calendar.badge.exclamationmark")
                } else {
                    ForEach(filteredEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(store.petName(for: event.petID))
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(event.startTime, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            EventSummaryText(event: event)
                        }
                    }
                }
            }
        }
        .navigationTitle("Events")
    }
}

#Preview {
    NavigationStack {
        EventListView()
            .environmentObject(PetCareStore.preview)
    }
}
