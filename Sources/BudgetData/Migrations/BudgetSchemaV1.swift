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

public enum BudgetMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BudgetSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
