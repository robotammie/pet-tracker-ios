import Foundation

enum EventCreationRoute: Identifiable {
    case event(CareEventType)
    case savedOptions(CareEventType)

    var id: String {
        switch self {
        case let .event(type):
            return "event-\(type.rawValue)"
        case let .savedOptions(type):
            return "saved-options-\(type.rawValue)"
        }
    }
}
