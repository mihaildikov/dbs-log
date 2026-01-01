import Foundation
import SwiftData

enum EventType: String, CaseIterable, Identifiable, Codable {
    case dyskinesia
    case dystonia
    case wearingOff
    case tremor
    case bradykinesia
    case rigidity
    case batteryCharge
    case stimulationChange
    case physicalActivity
    case feelsGood

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dyskinesia:
            "Dyskinesia"
        case .dystonia:
            "Dystonia"
        case .wearingOff:
            "Wearing OFF"
        case .tremor:
            "Tremor"
        case .bradykinesia:
            "Bradykinesia"
        case .rigidity:
            "Rigidity"
        case .batteryCharge:
            "Battery Charge"
        case .stimulationChange:
            "Stimulation Change"
        case .physicalActivity:
            "Physical Activity"
        case .feelsGood:
            "Feels Good"
        }
    }
}

enum EventStatus: String, CaseIterable, Identifiable, Codable {
    case pending
    case completed
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            "Pending"
        case .completed:
            "Completed"
        case .archived:
            "Archived"
        }
    }
}

@Model
final class Event {
    var id: UUID = Foundation.UUID()
    var timestamp: Date = Foundation.Date.now
    var typeRaw: String = EventType.dyskinesia.rawValue
    var subtype: String?
    var notes: String?
    var stateRaw: String = EventStatus.pending.rawValue

    init(id: UUID = UUID(), timestamp: Date, type: EventType, subtype: String? = nil, notes: String? = nil, state: EventStatus = .pending) {
        self.id = id
        self.timestamp = timestamp
        self.typeRaw = type.rawValue
        self.subtype = subtype
        if let notes, notes.count > 200 {
            self.notes = String(notes.prefix(200))
        } else {
            self.notes = notes
        }
        self.stateRaw = state.rawValue
    }

    var type: EventType {
        get { EventType(rawValue: typeRaw) ?? .dyskinesia }
        set { typeRaw = newValue.rawValue }
    }

    var state: EventStatus {
        get { EventStatus(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }
}
