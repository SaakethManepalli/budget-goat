import Foundation
import BudgetCore

#if canImport(UIKit)
import UIKit
#endif

#if canImport(LinkKit)
import LinkKit
#endif

public struct PlaidLinkSuccess: Sendable {
    public let publicToken: String
    public let institutionId: String
    public let institutionName: String

    public init(publicToken: String, institutionId: String, institutionName: String) {
        self.publicToken = publicToken
        self.institutionId = institutionId
        self.institutionName = institutionName
    }
}

// MARK: - iOS

#if canImport(UIKit)

public protocol PlaidLinkPresenting: Sendable {
    @MainActor
    func presentLink(on host: UIViewController, linkToken: String) async throws -> PlaidLinkSuccess
    @MainActor
    func resumeAfterRedirect(_ url: URL) -> Bool
}

@MainActor
public final class PlaidLinkCoordinator: NSObject, PlaidLinkPresenting {

    // Retains the LinkKit Handler for the duration of the Link session.
    // Without this, the handler is deallocated immediately and Link never opens.
    #if canImport(LinkKit)
    private var retainedHandler: (any Handler)?
    #endif

    public override init() { super.init() }

    public func presentLink(on host: UIViewController, linkToken: String) async throws -> PlaidLinkSuccess {
        #if canImport(LinkKit)
        return try await presentNative(on: host, linkToken: linkToken)
        #else
        throw BudgetError.linkFailed(
            "LinkKit SDK not installed. Run xcodegen generate after adding it to project.yml."
        )
        #endif
    }

    /// Resumes an in-flight Plaid Link OAuth flow after the bank redirects
    /// back to the app. Call this from `onOpenURL` in the scene/app.
    /// Returns `true` if the URL was handled by Plaid.
    @discardableResult
    public func resumeAfterRedirect(_ url: URL) -> Bool {
        #if canImport(LinkKit)
        guard let handler = retainedHandler else { return false }
        handler.resumeAfterTermination(from: url)
        return true
        #else
        return false
        #endif
    }
 
    #if canImport(LinkKit)
    private func presentNative(on host: UIViewController, linkToken: String) async throws -> PlaidLinkSuccess {
        return try await withCheckedThrowingContinuation { continuation in

            var config = LinkTokenConfiguration(
                token: linkToken,
                onSuccess: { [weak self] success in
                    self?.retainedHandler = nil
                    continuation.resume(returning: PlaidLinkSuccess(
                        publicToken: success.publicToken,
                        institutionId: success.metadata.institution.id,
                        institutionName: success.metadata.institution.name
                    ))
                }
            )

            // Called when: user taps Cancel, swipes to dismiss, or an error occurs.
            config.onExit = { [weak self] exit in
                self?.retainedHandler = nil
                if let error = exit.error {
                    // Plaid returned an error (e.g. invalid credentials, institution unavailable)
                    let message = error.displayMessage ?? error.errorCode.description
                    continuation.resume(throwing: BudgetError.linkFailed(message))
                } else {
                    // User deliberately cancelled — not an error condition
                    continuation.resume(throwing: BudgetError.linkCancelled)
                }
            }

            switch Plaid.create(config) {
            case .failure(let error):
                continuation.resume(throwing: BudgetError.linkFailed(error.localizedDescription))
            case .success(let handler):
                retainedHandler = handler
                handler.open(presentUsing: .viewController(host))
            }
        }
    }
    #endif
}

// MARK: - macOS stub

#else

public protocol PlaidLinkPresenting: Sendable {
    func presentLink(linkToken: String) async throws -> PlaidLinkSuccess
    func resumeAfterRedirect(_ url: URL) -> Bool
}

public final class PlaidLinkCoordinator: PlaidLinkPresenting, @unchecked Sendable {
    public init() {}
    public func presentLink(linkToken: String) async throws -> PlaidLinkSuccess {
        throw BudgetError.linkFailed("Plaid Link requires iOS UIKit runtime")
    }
    public func resumeAfterRedirect(_ url: URL) -> Bool { false }
}

#endif
