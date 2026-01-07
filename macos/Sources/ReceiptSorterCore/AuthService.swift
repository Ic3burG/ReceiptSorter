import Foundation
@preconcurrency import AppAuth
import AuthenticationServices

@MainActor
public final class AuthService: NSObject {
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    
    private let kIssuer = "https://accounts.google.com"
    private let kClientID: String
    private let kClientSecret: String? // Optional, but required for Google Desktop flow
    private let kRedirectURI = "http://127.0.0.1"
    private let kAuthStateKey = "authState"
    
    private let lock = NSLock()
    private var _authState: OIDAuthState?
    
    private var authState: OIDAuthState? {
        get { lock.withLock { _authState } }
        set { lock.withLock { _authState = newValue } }
    }
    
    public init(clientID: String, clientSecret: String? = nil) {
        self.kClientID = clientID
        self.kClientSecret = clientSecret
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
                clientSecret: self.kClientSecret, // Pass secret here
                scopes: ["https://www.googleapis.com/auth/spreadsheets"],
                redirectURL: URL(string: self.kRedirectURI)!,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil
            )
            
            self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: window) { authState, error in
                Task { @MainActor in
                    // Stop listener
                    self.redirectHTTPHandler?.cancelHTTPListener()
                    self.redirectHTTPHandler = nil
                    
                    if let authState = authState {
                        self.setAuthState(authState)
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: AuthError.authFailed(error?.localizedDescription ?? "User cancelled"))
                    }
                }
            }
            // Link the flow to the handler so it can process the redirect
            handler.currentAuthorizationFlow = self.currentAuthorizationFlow
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

public enum AuthError: LocalizedError {
    case invalidIssuer
    case discoveryFailed(String)
    case authFailed(String)
    case notAuthorized
    case tokenRefreshFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidIssuer: return "Invalid Issuer URL."
        case .discoveryFailed(let msg): return "Discovery Failed: \(msg)"
        case .authFailed(let msg): return "Authentication Failed: \(msg)"
        case .notAuthorized: return "Not Authorized. Please sign in."
        case .tokenRefreshFailed(let msg): return "Token Refresh Failed: \(msg)"
        }
    }
}
