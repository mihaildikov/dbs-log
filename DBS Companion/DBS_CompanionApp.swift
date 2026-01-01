//
//  DBS_CompanionApp.swift
//  DBS Companion
//
//  Created by Mikhail Dikov on 12/30/25.
//

import SwiftUI
import SwiftData

@main
struct DBS_CompanionApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Event.self,
        ])
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.mixadu.DBS-Companion")
        )
        let localConfiguration = ModelConfiguration("Local", schema: schema, isStoredInMemoryOnly: false)
        let isUITest = ProcessInfo.processInfo.arguments.contains("UITests")
        let isTestEnvironment = isUITest || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        do {
            if isTestEnvironment {
                let testConfiguration = ModelConfiguration("Test", schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [testConfiguration])
            }
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            logModelContainerError(error, label: "CloudKit container failed, falling back to local storage")
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                logModelContainerError(error, label: "Local container failed")
                fatalError("Could not create local ModelContainer: \(error)")
            }
        }
    }()

    private static func logModelContainerError(_ error: Error, label: String) {
        let nsError = error as NSError
        print("[DBS Log] \(label)")
        print("[DBS Log] error: \(error)")
        print("[DBS Log] domain: \(nsError.domain) code: \(nsError.code)")
        print("[DBS Log] userInfo: \(nsError.userInfo)")
    }

    private static func logModelContainerNote(_ message: String) {
        print("[DBS Log] \(message)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
