import Foundation
import SwiftData

public enum BudgetSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            BankAccountModel.self,
            TransactionModel.self,
            BudgetModel.self,
            RecurringPatternModel.self,
            ExchangeRateModel.self,
        ]
    }
}

/// SwiftData migration plan.
///
/// # Adding a new schema version
///
/// When a model changes in a breaking way (removed property, new non-optional
/// field, changed relationship rule), do NOT edit V1 — create `BudgetSchemaV2`
/// and register a stage:
///
/// ```swift
/// public enum BudgetSchemaV2: VersionedSchema {
///     public static var versionIdentifier = Schema.Version(2, 0, 0)
///     public static var models: [any PersistentModel.Type] { [...] }
/// }
///
/// public enum BudgetMigrationPlan: SchemaMigrationPlan {
///     public static var schemas: [any VersionedSchema.Type] {
///         [BudgetSchemaV1.self, BudgetSchemaV2.self]
///     }
///     public static var stages: [MigrationStage] {
///         [
///             .custom(
///                 fromVersion: BudgetSchemaV1.self,
///                 toVersion:   BudgetSchemaV2.self,
///                 willMigrate: nil,
///                 didMigrate:  { context in
///                     // Backfill new non-optional fields here,
///                     // transform legacy data, then `try context.save()`.
///                 }
///             )
///         ]
///     }
/// }
/// ```
///
/// # Additive-only changes
///
/// If the only change is adding an optional property (nullable default),
/// SwiftData handles it automatically via `.lightweight` — no stage needed.
public enum BudgetMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BudgetSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []   // No migrations yet — we are at V1.
    }
}
