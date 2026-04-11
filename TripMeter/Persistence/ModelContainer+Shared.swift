import Foundation
import SwiftData

enum Persistence {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([Trip.self, Note.self])
        let storeURL = storeFileURL()
        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func storeFileURL() -> URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupId) {
            return groupURL.appendingPathComponent("TripMeter.store")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TripMeter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("TripMeter.store")
    }
}
