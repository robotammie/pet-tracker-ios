import Foundation

final class LitterEventFormViewModel: ObservableObject {
    @Published var timestamp: Date = .now
}
