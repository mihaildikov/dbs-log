import Foundation
@testable import DBS_Companion
import Testing

@MainActor
struct EventTranscriptParserTests {

    @Test func parses_type_subtype_and_time() async throws {
        let parser = EventTranscriptParser()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let draft = parser.parse("Record event dystonia, sub type shoulder pull at 09:15 after Rytary", now: now)

        #expect(draft.type == .dystonia)
        #expect(draft.subtype == "Shoulder Pull")
        #expect(draft.timestamp != nil)
    }

    @Test func parses_wearing_off_variants() async throws {
        let parser = EventTranscriptParser()
        let now = Date()
        let draft = parser.parse("Event wearing off at 9:50", now: now)

        #expect(draft.type == .wearingOff)
        #expect(draft.timestamp != nil)
    }

    @Test func warns_when_type_missing() async throws {
        let parser = EventTranscriptParser()
        let now = Date()
        let draft = parser.parse("Just notes without clear type", now: now)

        #expect(draft.type == nil)
        #expect(draft.parseWarnings.contains("Couldn't detect event type."))
    }

    @Test func parses_bradykinesia_keywords() async throws {
        let parser = EventTranscriptParser()
        let now = Date()
        let draft = parser.parse("Feeling slow with slowness in the afternoon", now: now)

        #expect(draft.type == .bradykinesia)
    }

    @Test func parses_rigidity_keywords() async throws {
        let parser = EventTranscriptParser()
        let now = Date()
        let draft = parser.parse("Noting stiffness and spasms after lunch", now: now)

        #expect(draft.type == .rigidity)
    }

    @Test func parses_medication_keywords() async throws {
        let parser = EventTranscriptParser()
        let now = Date()
        let draft = parser.parse("Took meds after breakfast", now: now)

        #expect(draft.type == .medication)
    }
}
