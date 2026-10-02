//
//  SyncMonitor.swift
//  Notes
//
//  Surfaces iCloud sync activity from NSPersistentCloudKitContainer events.
//

import CloudKit
import CoreData
import Observation

@MainActor
@Observable
final class SyncMonitor {

    // Setup or import in flight: notes may still be arriving from iCloud
    private(set) var isDownloading = false
    // Last failure in user-facing words; cleared by the next successful event
    private(set) var errorMessage: String?

    @ObservationIgnored private var inFlight: [UUID: NSPersistentCloudKitContainer.EventType] = [:]

    init(container: NSPersistentCloudKitContainer) {
        Task { [weak self] in
            let events = NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification,
                object: container)
            for await notification in events {
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else { continue }
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            inFlight[event.identifier] = event.type
        } else {
            inFlight[event.identifier] = nil
            if event.succeeded {
                errorMessage = nil
            } else if let error = event.error {
                errorMessage = Self.message(for: error)
            }
        }
        isDownloading = inFlight.values.contains { $0 == .setup || $0 == .import }
    }

    private static func message(for error: Error) -> String {
        switch (error as? CKError)?.code {
        case .notAuthenticated:
            return "iCloud is off. Notes stay on this device"
        case .quotaExceeded:
            return "iCloud storage is full"
        case .networkUnavailable, .networkFailure:
            return "Offline. Will sync when connected"
        default:
            return "iCloud sync paused"
        }
    }
}
