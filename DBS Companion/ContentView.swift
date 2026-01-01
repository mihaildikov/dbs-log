//
//  ContentView.swift
//  DBS Companion
//
//  Created by Mikhail Dikov on 12/30/25.
//

import SwiftUI
import SwiftData

enum AddEventInputMethod: String, CaseIterable, Identifiable {
    case text
    case voice
    case camera

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text:
            "Text / Manual entry"
        case .voice:
            "Voice input"
        case .camera:
            "Camera / photo input"
        }
    }

    var icon: String {
        switch self {
        case .text:
            "doc.text"
        case .voice:
            "mic"
        case .camera:
            "camera"
        }
    }

    var mode: NewEventMode {
        switch self {
        case .text:
            .manual
        case .voice:
            .voice
        case .camera:
            .camera
        }
    }
}

enum AppRoute: Hashable {
    case newEvent(AddEventInputMethod)
    case newEventPrefilled(AddEventInputMethod, ParsedEventDraft, Bool)
    case share([UUID])
    case photo
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.timestamp, order: .reverse) private var events: [Event]

    @State private var path: [AppRoute] = []
    @State private var showActionSheet = false
    @State private var pendingDeleteIDs: [UUID] = []
    @State private var showDeleteAlert = false
    @State private var selectedStatus: EventStatus = .pending
    @State private var pendingCompleteID: UUID?
    @State private var showCompleteAlert = false
    @State private var pendingCompleteIDs: [UUID] = []
    @State private var showGroupCompleteAlert = false
    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 12) {
                headerView
                eventList
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showActionSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityIdentifier("addEventButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isSelecting ? "Done" : "Select") {
                        if isSelecting {
                            isSelecting = false
                            selectedIDs.removeAll()
                        } else {
                            isSelecting = true
                        }
                    }
                    .disabled(events.isEmpty)
                    .accessibilityIdentifier("selectEventsButton")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Add event", isPresented: $showActionSheet, titleVisibility: .visible) {
                ForEach(AddEventInputMethod.allCases) { method in
                    Button {
                        if method == .camera {
                            path.append(.photo)
                        } else {
                            path.append(AppRoute.newEvent(method))
                        }
                    } label: {
                        Label(method.label, systemImage: method.icon)
                    }
                    .accessibilityIdentifier("addEventOption_\(method.rawValue)")
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSelecting && !selectedIDs.isEmpty {
                    selectionToolbar
                }
            }
            .alert("Delete events?", isPresented: $showDeleteAlert, actions: {
                Button("Delete", role: .destructive) {
                    deleteEvents(with: pendingDeleteIDs)
                    pendingDeleteIDs = []
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteIDs = []
                }
            }, message: {
                Text("This will remove the selected events from the log.")
            })
            .alert("Mark as completed?", isPresented: $showCompleteAlert, actions: {
                Button("Complete", role: .destructive) {
                    if let id = pendingCompleteID, let event = events.first(where: { $0.id == id }) {
                        markComplete(event)
                    }
                    pendingCompleteID = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingCompleteID = nil
                }
            }, message: {
                Text("This will move the event to Completed status.")
            })
            .alert("Complete selected events?", isPresented: $showGroupCompleteAlert, actions: {
                Button("Complete", role: .destructive) {
                    markCompleteEvents(with: pendingCompleteIDs)
                    pendingCompleteIDs = []
                }
                Button("Cancel", role: .cancel) {
                    pendingCompleteIDs = []
                }
            }, message: {
                Text("This will move the selected events to Completed status.")
            })
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Event log")
                .font(.largeTitle.weight(.semibold))

            Picker("Status", selection: $selectedStatus) {
                ForEach([EventStatus.pending, EventStatus.completed], id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("statusPicker")

            if isSelecting {
                Text("\(selectedIDs.count) selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eventList: some View {
        List {
            if sectionedEvents.isEmpty {
                let pendingText = "Tap + to create a new event. Swipe right to complete. Swipe left to delete."
                let completedText = "When a pending event is processed, swipe right to complete. Swipe left to delete."
                Text(selectedStatus == .completed ? completedText : pendingText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ForEach(sectionedEvents, id: \.date) { section in
                Section(header: Text(dayFormatter.string(from: section.date))) {
                    ForEach(section.events) { event in
                        row(for: event)
                    }
                    .onDelete { offsets in
                        confirmDelete(offsets: offsets, in: section.events)
                    }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("eventList")
    }

    @ViewBuilder
    private func row(for event: Event) -> some View {
        if isSelecting {
            HStack(spacing: 12) {
                Image(systemName: selectedIDs.contains(event.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedIDs.contains(event.id) ? .blue : .secondary)
                EventRow(event: event, timeFormatter: timeFormatter)
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleSelection(event.id) }
        } else {
            NavigationLink {
                EventDetailView(event: event)
            } label: {
                EventRow(event: event, timeFormatter: timeFormatter)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if event.state == .pending {
                    Button {
                        pendingCompleteID = event.id
                        showCompleteAlert = true
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .newEvent(let method):
            NewEventView(mode: method.mode, initialDraft: nil, autoStartVoice: false) { event in
                modelContext.insert(event)
                resetSelection()
                path.removeAll()
            }
        case .newEventPrefilled(let method, let draft, let autoStartVoice):
            NewEventView(mode: method.mode, initialDraft: draft, autoStartVoice: autoStartVoice) { event in
                modelContext.insert(event)
                resetSelection()
                path.removeAll()
            }
        case .share(let ids):
            let selectedEvents = events.filter { ids.contains($0.id) }
            ShareEventsView(events: selectedEvents)
        case .photo:
            PhotoCaptureView { draft in
                path.append(.newEventPrefilled(.camera, draft, false))
            } onManual: {
                path.append(.newEvent(.text))
            }
            }
    }

    private func confirmDelete(offsets: IndexSet, in sectionEvents: [Event]) {
        let ids = offsets.compactMap { index in
            sectionEvents.indices.contains(index) ? sectionEvents[index].id : nil
        }
        pendingDeleteIDs = ids
        showDeleteAlert = true
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func deleteEvents(with ids: [UUID]) {
        guard !ids.isEmpty else { return }
        withAnimation {
            for id in ids {
                if let event = events.first(where: { $0.id == id }) {
                    event.state = .archived
                }
            }
            resetSelection()
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            if selectedStatus == .pending {
                Button {
                    let selected = Array(selectedIDs)
                    path.append(.share(selected))
                    resetSelection()
                } label: {
                    selectionActionLabel(title: "Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(selectedIDs.isEmpty)
                .accessibilityIdentifier("shareSelectionButton")

                Button {
                    pendingCompleteIDs = Array(selectedIDs)
                    showGroupCompleteAlert = true
                } label: {
                    selectionActionLabel(title: "Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(selectedIDs.isEmpty)
                .accessibilityIdentifier("completeSelectionButton")
            }

            Button(role: .destructive) {
                pendingDeleteIDs = Array(selectedIDs)
                showDeleteAlert = true
            } label: {
                selectionActionLabel(title: "Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedIDs.isEmpty)
            .accessibilityIdentifier("deleteSelectionButton")
        }
        .padding()
        .background(.regularMaterial)
    }

    private var sectionedEvents: [(date: Date, events: [Event])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        let sortedKeys = grouped.keys.sorted(by: >)
        return sortedKeys.map { key in
            let dayEvents = (grouped[key] ?? []).sorted { $0.timestamp > $1.timestamp }
            return (date: key, events: dayEvents)
        }
    }

    private var filteredEvents: [Event] {
        events.filter { $0.state != .archived && $0.state == selectedStatus }
    }

    private func markComplete(_ event: Event) {
        withAnimation {
            event.state = .completed
        }
    }

    private func markCompleteEvents(with ids: [UUID]) {
        guard !ids.isEmpty else { return }
        withAnimation {
            for id in ids {
                if let event = events.first(where: { $0.id == id }) {
                    event.state = .completed
                }
            }
            resetSelection()
        }
    }

    private func selectionActionLabel(title: String, systemImage: String) -> some View {
        ViewThatFits(in: .horizontal) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: systemImage)
        }
    }

    private func resetSelection() {
        isSelecting = false
        selectedIDs.removeAll()
    }
}

struct EventRow: View {
    let event: Event
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            Text(timeFormatter.string(from: event.timestamp))
                .font(.headline.weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(.yellow.opacity(0.8))
                .clipShape(Capsule())

            Text(event.type.displayName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Event.self, inMemory: true)
}
