import Foundation
import SwiftData
import BudgetCore
import BudgetData
import PlaidKit
import SecureStorage
import TransactionEngine

@MainActor
public final class AppDependencies: ObservableObject {

    public let modelContainer: ModelContainer
    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let budgetRepo: BudgetRepository
    public let recurringRepo: RecurringRepository
    public let cursorStore: CursorStore
    public let tokenStore: SecureTokenStoring
    public let biometricAuth: BiometricAuthenticating
    public let syncProvider: BankSyncProvider
    public let linkPresenter: PlaidLinkPresenting
    public let categorizationEngine: CategorizationEngine?
    public let syncUseCase: SyncTransactionsUseCase
    public let linkUseCase: LinkAccountUseCase
    public let exportUseCase: ExportDataUseCase
    public let resetUseCase: ResetDataUseCase
    public let webhookBus: WebhookEventBus
    public let recurringDetector: RecurringDetector
    public let reauthCoordinator: ReauthCoordinator

    public init(configuration: Configuration) throws {
        self.modelContainer = try configuration.containerFactory()
        let transactionRepo = TransactionRepositoryImpl(
            container: modelContainer,
            baseCurrency: configuration.baseCurrency
        )
        let accountRepo = AccountRepositoryImpl(container: modelContainer)
        self.transactionRepo = transactionRepo
        self.accountRepo = accountRepo
        self.budgetRepo = BudgetRepositoryImpl(container: modelContainer, transactionRepo: transactionRepo)
        self.recurringRepo = RecurringRepositoryImpl(container: modelContainer)
        self.cursorStore = UserDefaultsCursorStore()
        self.tokenStore = SecureTokenStore(configuration: configuration.keychainConfiguration)
        self.biometricAuth = BiometricAuthenticator()

        let proxy = URLSessionBackendProxyClient(configuration: configuration.proxyConfiguration)
        self.syncProvider = PlaidSyncProvider(proxy: proxy, tokenStore: tokenStore)
        self.linkPresenter = PlaidLinkCoordinator()

        self.syncUseCase = SyncTransactionsUseCase(
            syncProvider: syncProvider,
            transactionRepo: transactionRepo,
            accountRepo: accountRepo,
            cursorStore: cursorStore
        )
        self.linkUseCase = LinkAccountUseCase(
            syncProvider: syncProvider,
            accountRepo: accountRepo,
            syncUseCase: syncUseCase
        )

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.exportUseCase = ExportDataUseCase(
            accountRepo: accountRepo,
            transactionRepo: transactionRepo,
            budgetRepo: self.budgetRepo,
            recurringRepo: self.recurringRepo,
            appVersion: appVersion
        )
        self.resetUseCase = ResetDataUseCase(
            accountRepo: accountRepo,
            transactionRepo: transactionRepo,
            budgetRepo: self.budgetRepo,
            recurringRepo: self.recurringRepo,
            tokenStore: self.tokenStore,
            cursorStore: self.cursorStore,
            syncProvider: self.syncProvider
        )

        if let llm = configuration.llmClient {
            self.categorizationEngine = CategorizationPipeline(llmClient: llm)
        } else {
            self.categorizationEngine = nil
        }

        self.webhookBus = WebhookEventBus()
        self.recurringDetector = RecurringDetector()
        self.reauthCoordinator = ReauthCoordinator()
    }

    public struct Configuration {
        public let baseCurrency: CurrencyCode
        public let containerFactory: () throws -> ModelContainer
        public let keychainConfiguration: SecureTokenStore.Configuration
        public let proxyConfiguration: BackendProxyConfiguration
        public let llmClient: LLMCategorizationClient?

        public init(
            baseCurrency: CurrencyCode = .usd,
            containerFactory: @escaping () throws -> ModelContainer = ModelContainerFactory.makeProduction,
            keychainConfiguration: SecureTokenStore.Configuration = .production,
            proxyConfiguration: BackendProxyConfiguration,
            llmClient: LLMCategorizationClient? = nil
        ) {
            self.baseCurrency = baseCurrency
            self.containerFactory = containerFactory
            self.keychainConfiguration = keychainConfiguration
            self.proxyConfiguration = proxyConfiguration
            self.llmClient = llmClient
        }
    }
}
