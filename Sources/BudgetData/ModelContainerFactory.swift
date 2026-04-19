import Foundation
import SwiftData

public enum ModelContainerFactory {

    public static func makeProduction() throws -> ModelContainer {
        let schema = Schema(BudgetSchemaV1.models)
        let url = try storeURL()
        let config = ModelConfiguration(
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: BudgetMigrationPlan.self,
            configurations: config
        )
    }

    public static func makeInMemory() throws -> ModelContainer {
        let schema = Schema(BudgetSchemaV1.models)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    private static func storeURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("BudgetGoat", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var protected = URLResourceValues()
        protected.isExcludedFromBackup = true
        var mutableDir = dir
        try? mutableDir.setResourceValues(protected)
        return dir.appendingPathComponent("BudgetGoat.store")
    }
}
