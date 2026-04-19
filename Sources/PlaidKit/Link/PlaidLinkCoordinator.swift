import Foundation
import BudgetCore

#if canImport(UIKit)
import UIKit
import SafariServices
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

#if canImport(UIKit)

public protocol PlaidLinkPresenting: Sendable {
    @MainActor
    func presentLink(on host: UIViewController, linkToken: String) async throws -> PlaidLinkSuccess
}

@MainActor
public final class PlaidLinkCoordinator: NSObject, PlaidLinkPresenting {

    public override init() { super.init() }

    public func presentLink(on host: UIViewController, linkToken: String) async throws -> PlaidLinkSuccess {
        #if canImport(LinkKit)
        return try await presentNative(on: host, linkToken: linkToken)
        #else
        return try await presentWebFallback(on: host, linkToken: linkToken)
        #endif
    }

    private func presentWebFallback(on host: UIViewController, linkToken: String) async throws -> PlaidLinkSuccess {
        guard let url = URL(string: "https://cdn.plaid.com/link/v2/stable/link.html?isWebview=true&token=\(linkToken)") else {
            throw BudgetError.linkFailed("invalid link URL")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let sfvc = SFSafariViewController(url: url)
            sfvc.modalPresentationStyle = .formSheet
            sfvc.delegate = LinkSafariDelegate.shared
            LinkSafariDelegate.shared.continuation = continuation
            host.present(sfvc, animated: true)
        }
    }

    #if canImport(LinkKit)
    private func presentNative(on host: UIViewController, linkToken: String) async throws -> PlaidLinkSuccess {
        throw BudgetError.linkFailed("LinkKit native path stub — wire up when SDK is added as dependency")
    }
    #endif
}

private final class LinkSafariDelegate: NSObject, SFSafariViewControllerDelegate, @unchecked Sendable {
    static let shared = LinkSafariDelegate()
    var continuation: CheckedContinuation<PlaidLinkSuccess, Error>?

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        continuation?.resume(throwing: BudgetError.linkCancelled)
        continuation = nil
    }
}

#else

public protocol PlaidLinkPresenting: Sendable {
    func presentLink(linkToken: String) async throws -> PlaidLinkSuccess
}

public final class PlaidLinkCoordinator: PlaidLinkPresenting, @unchecked Sendable {
    public init() {}

    public func presentLink(linkToken: String) async throws -> PlaidLinkSuccess {
        throw BudgetError.linkFailed("Plaid Link requires iOS UIKit runtime")
    }
}

#endif
