import Foundation
@preconcurrency import AppAuth
import AuthenticationServices

@MainActor
public final class AuthService: NSObject {
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    
    private let kIssuer = "https://accounts.google.com"
    private let kClientID: String
    private let kAuthStateKey = "authState"
    
    private var authState: OIDAuthState?
    
    public nonisolated init(clientID: String) {
        self.kClientID = clientID
        super.init()
        Task { @MainActor in
            self.loadState()
        }
    }
    
    public var isAuthorized: Bool {
        return authState?.isAuthorized ?? false
    }
    
    public func signIn(presenting window: NSWindow) async throws {
        // 1. Start the Loopback Listener
        let handler = OIDRedirectHTTPHandler(successURL: nil)
        let redirectURI = handler.startHTTPListener(nil)
        self.redirectHTTPHandler = handler
        
        // 2. Configure Google Endpoints
        let authEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
        let config = OIDServiceConfiguration(authorizationEndpoint: authEndpoint, tokenEndpoint: tokenEndpoint)

        // 3. Perform Auth Request
        return try await withCheckedThrowingContinuation { continuation in
            let request = OIDAuthorizationRequest(
                configuration: config,
                clientId: self.kClientID,
                scopes: ["https://www.googleapis.com/auth/spreadsheets"],
                redirectURL: redirectURI,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil
            )
            
            self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: window) { authState, error in
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

public enum AuthError: Error {
    case invalidIssuer
    case discoveryFailed(String)
    case authFailed(String)
    case notAuthorized
    case tokenRefreshFailed(String)
}
