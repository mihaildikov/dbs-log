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
}

enum AppRoute: Hashable {
    case newEvent(AddEventInputMethod)
    case selectEvents
    case share([UUID])
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.timestamp, order: .reverse) private var events: [Event]

    @State private var path = NavigationPath()
    @State private var showActionSheet = false

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DBS Companion")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Event log")
                        .font(.largeTitle.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                List {
                    ForEach(events) { event in
                        EventRow(event: event, timeFormatter: timeFormatter)
                    }
                }
                .listStyle(.plain)
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showActionSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !events.isEmpty {
                        Button("Select") {
                            path.append(AppRoute.selectEvents)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Add event", isPresented: $showActionSheet, titleVisibility: .visible) {
                ForEach(AddEventInputMethod.allCases) { method in
                    Button {
                        path.append(AppRoute.newEvent(method))
                    } label: {
                        Label(method.label, systemImage: method.icon)
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .newEvent(let method):
                    NewEventView(inputMethod: method) { event in
                        modelContext.insert(event)
                    }
                case .selectEvents:
                    SelectEventsView(events: events) { selected in
                        path.append(AppRoute.share(Array(selected)))
                    }
                case .share(let ids):
                    let selectedEvents = events.filter { ids.contains($0.id) }
                    ShareEventsView(events: selectedEvents)
                }
            }
        }
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
