import Foundation
import SwiftData

enum EventType: String, CaseIterable, Identifiable, Codable {
    case dyskinesia
    case dystonia
    case wearingOff

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dyskinesia:
            "Dyskinesia"
        case .dystonia:
            "Dystonia"
        case .wearingOff:
            "Wearing OFF"
        }
    }
}

@Model
final class Event {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var typeRaw: String
    var subtype: String?
    var notes: String?

    init(id: UUID = UUID(), timestamp: Date, type: EventType, subtype: String? = nil, notes: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.typeRaw = type.rawValue
        self.subtype = subtype
        self.notes = notes
    }

    var type: EventType {
        get { EventType(rawValue: typeRaw) ?? .dyskinesia }
        set { typeRaw = newValue.rawValue }
    }
}
