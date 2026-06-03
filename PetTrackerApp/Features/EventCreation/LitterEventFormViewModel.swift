import Foundation

final class LitterEventFormViewModel: ObservableObject {
    @Published var timestamp: Date = .now

    func makeEvent() -> CareEvent {
        CareEvent(
            type: .litter,
            petID: nil,
            startTime: timestamp,
            data: .litter(LitterEventData())
        )
    }
}
