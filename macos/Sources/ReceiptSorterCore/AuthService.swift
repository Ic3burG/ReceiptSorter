import Foundation
@preconcurrency import AppAuth
import AuthenticationServices

public final class AuthService: NSObject, @unchecked Sendable {
    @MainActor private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    private let kIssuer = "https://accounts.google.com"
    private let kClientID: String
    private let kRedirectURI = "http://127.0.0.1" // Loopback without path
    private let kAuthStateKey = "authState"
    
    private let lock = NSLock()
    private var _authState: OIDAuthState?
    
    private var authState: OIDAuthState? {
        get { lock.withLock { _authState } }
        set { lock.withLock { _authState = newValue } }
    }
    
    public init(clientID: String) {
        self.kClientID = clientID
        super.init()
        self.loadState()
    }
    
    public var isAuthorized: Bool {
        return authState?.isAuthorized ?? false
    }
    
    @MainActor
    public func signIn(presenting window: NSWindow) async throws {
        let authEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
        let config = OIDServiceConfiguration(authorizationEndpoint: authEndpoint, tokenEndpoint: tokenEndpoint)

        return try await withCheckedThrowingContinuation { continuation in
            let request = OIDAuthorizationRequest(
                configuration: config,
                clientId: self.kClientID,
                scopes: ["https://www.googleapis.com/auth/spreadsheets"],
                redirectURL: URL(string: self.kRedirectURI)!,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil
            )
            
            let flow = OIDAuthState.authState(byPresenting: request, presenting: window) { authState, error in
                if let authState = authState {
                    self.setAuthState(authState)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AuthError.authFailed(error?.localizedDescription ?? "User cancelled"))
                }
            }
            self.currentAuthorizationFlow = flow
        }
    }
    
    public func signOut() {
        self.authState = nil
        UserDefaults.standard.removeObject(forKey: kAuthStateKey)
    }
    
    public func performAction(action: @escaping @Sendable (String) async throws -> Void) async throws {
        guard let authState = self.authState else {
            throw AuthError.notAuthorized
        }
        
        let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            // performAction is thread-safe in AppAuth
            authState.performAction { accessToken, idToken, error in
                if let accessToken = accessToken {
                    continuation.resume(returning: accessToken)
                } else {
                    continuation.resume(throwing: AuthError.tokenRefreshFailed(error?.localizedDescription ?? "Unknown"))
                }
            }
        }
        
        self.saveState()
        try await action(token)
    }
    
    private func saveState() {
        guard let authState = authState else { return }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: kAuthStateKey)
        }
    }
    
    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: kAuthStateKey),
           let state = try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data) {
            self.authState = state
        }
    }
    
    private func setAuthState(_ state: OIDAuthState) {
        self.authState = state
        self.saveState()
    }
}

public enum AuthError: Error {
    case invalidIssuer
    case discoveryFailed(String)
    case authFailed(String)
    case notAuthorized
    case tokenRefreshFailed(String)
}
