import Foundation
@preconcurrency import AppAuth
import AuthenticationServices
#if canImport(AppKit)
import AppKit
@preconcurrency import AppAuthCore
#endif

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public final class AuthService: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    #if canImport(AppKit)
    private var redirectHTTPHandler: OIDRedirectHTTPHandler?
    #endif
    
    private let kIssuer = "https://accounts.google.com"
    private let kClientID: String
    private let kClientSecret: String?
    private let kRedirectURI = "http://127.0.0.1"
    private let kAuthStateKey = "authState"
    
    private var _authState: OIDAuthState?
    private var authState: OIDAuthState? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _authState
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _authState = newValue
        }
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
    
    #if canImport(AppKit)
    public func signIn(presenting window: NSWindow) async throws {
        let authEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
        let config = OIDServiceConfiguration(authorizationEndpoint: authEndpoint, tokenEndpoint: tokenEndpoint)

        return try await withCheckedThrowingContinuation { continuation in
            // Start Loopback Listener
            let handler = OIDRedirectHTTPHandler(successURL: nil)
            let redirectURI = handler.startHTTPListener(nil)
            self.redirectHTTPHandler = handler
            
            // Update request with dynamic port
            let requestWithPort = OIDAuthorizationRequest(
                configuration: config,
                clientId: self.kClientID,
                clientSecret: self.kClientSecret,
                scopes: ["https://www.googleapis.com/auth/spreadsheets"],
                redirectURL: redirectURI,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil
            )
            
            self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: requestWithPort, presenting: window) { authState, error in
                self.redirectHTTPHandler?.cancelHTTPListener()
                
                if let authState = authState {
                    self.setAuthState(authState)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AuthError.authFailed(error?.localizedDescription ?? "User cancelled"))
                }
            }
            
            handler.currentAuthorizationFlow = self.currentAuthorizationFlow
        }
    }
    #endif
    
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
