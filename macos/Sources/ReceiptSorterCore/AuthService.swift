import Foundation
@preconcurrency import AppAuth
import AuthenticationServices

@available(macOS 13.0, *)
public actor AuthService: NSObject, @unchecked Sendable {
    private var authFlow: OIDExternalUserAgentSession?
    private let kIssuer = "https://accounts.google.com"
    private let kClientID: String
    private let kRedirectURI = "http://127.0.0.1:0/callback"
    
    private let kAuthStateKey = "authState"
    private var authState: OIDAuthState?
    
    public init(clientID: String) {
        self.kClientID = clientID
        super.init()
        self.loadStateSync()
    }
    
    public func isAuthorized() -> Bool {
        return authState?.isAuthorized ?? false
    }
    
    @MainActor
    public func signIn(presenting window: NSWindow) async throws {
        let request = try await self.createAuthRequest()
        
        return try await withCheckedThrowingContinuation { continuation in
            let flow = OIDAuthState.authState(byPresenting: request, presenting: window) { authState, error in
                if let authState = authState {
                    Task {
                        await self.updateAuthState(authState)
                        continuation.resume()
                    }
                } else {
                    continuation.resume(throwing: AuthError.authFailed(error?.localizedDescription ?? "User cancelled"))
                }
            }
            
            // We need to keep a reference to the flow
            Task { await self.setAuthFlow(flow) }
        }
    }
    
    private func createAuthRequest() async throws -> OIDAuthorizationRequest {
        return try await withCheckedThrowingContinuation { continuation in
            guard let issuer = URL(string: kIssuer) else {
                continuation.resume(throwing: AuthError.invalidIssuer)
                return
            }
            
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in
                guard let config = configuration else {
                    continuation.resume(throwing: AuthError.discoveryFailed(error?.localizedDescription ?? "Unknown"))
                    return
                }
                
                let request = OIDAuthorizationRequest(
                    configuration: config,
                    clientId: self.kClientID,
                    scopes: ["https://www.googleapis.com/auth/spreadsheets"],
                    redirectURL: URL(string: self.kRedirectURI)!,
                    responseType: OIDResponseTypeCode,
                    additionalParameters: nil
                )
                continuation.resume(returning: request)
            }
        }
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
    
    private func updateAuthState(_ state: OIDAuthState) {
        self.authState = state
        self.saveState()
    }
    
    private func setAuthFlow(_ flow: OIDExternalUserAgentSession) {
        self.authFlow = flow
    }
    
    private func saveState() {
        guard let authState = authState else { return }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: kAuthStateKey)
        }
    }
    
    private func loadStateSync() {
        if let data = UserDefaults.standard.data(forKey: kAuthStateKey),
           let state = try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data) {
            self.authState = state
        }
    }
}

public enum AuthError: Error {
    case invalidIssuer
    case discoveryFailed(String)
    case authFailed(String)
    case notAuthorized
    case tokenRefreshFailed(String)
}