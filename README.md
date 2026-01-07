# DBS Log
DBS Log helps capture detailed event notes while tuning the Medtronic Percept DBS stimulator. It is designed to track symptom events, context, and interventions so you can review patterns over time.

How to use
- Tap + to add a new event (manual, voice, or photo).
- Choose the event type, add optional details, and save.
- Use Select to share, complete, or delete multiple events.
- Review and edit an event from the list as needed.

Quick demo
- See the screenshots: [Quick demo](docs/quick-demo.md)

## DBS Log — Purpose Statement
DBS Log is designed to contextualize Medtronic Percept(TM) sensing data by pairing Percept scans with patient-reported symptoms, medication timing, and activity context, in order to facilitate more effective tuning of adaptive DBS (aDBS).

The patient captures high-value event data (e.g., OFF episodes, dyskinesia, rescue dosing, activity transitions) at or near the time Percept recordings are taken. Each event is annotated with:
- current symptoms and perceived state
- recent and active medications
- physical or cognitive activity
- time since last stimulation or medication change

Before the next programming visit, DBS Log generates a concise, structured report that aligns these contextual observations with Percept scan timestamps. This allows the clinical team to:
- interpret neural sensing data against real-world patient states
- distinguish stimulation effects from medication overlap
- identify meaningful thresholds and state transitions
- reduce reliance on retrospective recall
- accelerate aDBS parameter tuning

In practice, DBS Log turns Percept scans from isolated signal snapshots into clinically interpretable, patient-anchored evidence, improving the efficiency and precision of adaptive DBS programming.
