import SwiftUI

struct EventCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    let route: EventCreationRoute

    var body: some View {
        NavigationStack {
            List {
                Section {
                    destinationSummary
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var title: String {
        switch route {
        case let .event(type):
            return "Add \(type.rawValue)"
        case let .savedOptions(type):
            return "\(type.rawValue) Options"
        }
    }

    @ViewBuilder
    private var destinationSummary: some View {
        switch route {
        case let .event(type):
            Label("Creation form for \(type.rawValue) starts here", systemImage: icon(for: type))
                .foregroundStyle(.secondary)
        case let .savedOptions(type):
            Label("Saved \(type.rawValue.lowercased()) options start here", systemImage: "list.bullet.rectangle")
                .foregroundStyle(.secondary)
        }
    }

    private func icon(for type: CareEventType) -> String {
        switch type {
        case .food:
            return "fork.knife"
        case .medicine:
            return "pills"
        case .litter:
            return "sparkles"
        }
    }
}

#Preview {
    EventCreationSheet(route: .event(.food))
        .environmentObject(PetCareStore.preview)
}
