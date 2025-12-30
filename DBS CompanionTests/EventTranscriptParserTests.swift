@testable import DBS_Companion
import Testing

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
}
