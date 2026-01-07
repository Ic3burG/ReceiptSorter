import Foundation
import SwiftJWT

@available(macOS 13.0, *)
public actor SheetService {
    private let serviceAccountPath: String
    private let sheetID: String
    private var accessToken: String?
    private var tokenExpiration: Date?
    
    public init(serviceAccountPath: String, sheetID: String) {
        self.serviceAccountPath = serviceAccountPath
        self.sheetID = sheetID
    }
    
    public func appendReceipt(_ data: ReceiptData) async throws {
        let token = try await getAccessToken()
        
        let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(sheetID)/values/A1:append?valueInputOption=USER_ENTERED")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let rowValues: [Any] = [
            data.date ?? "",
            data.vendor ?? "",
            data.description ?? "",
            "", // Category (we can pass this in if we update ReceiptData to include it)
            data.total_amount ?? 0,
            data.currency ?? "",
            "Uploaded via macOS"
        ]
        
        let body: [String: Any] = [
            "values": [rowValues]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            if let errorText = String(data: responseData, encoding: .utf8) {
                throw SheetError.apiError(errorText)
            }
            throw SheetError.apiError("Unknown error")
        }
    }
    
    private func getAccessToken() async throws -> String {
        if let token = accessToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }
        
        // Load Service Account JSON
        let fileURL = URL(fileURLWithPath: serviceAccountPath)
        let data = try Data(contentsOf: fileURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let privateKeyPEM = json["private_key"] as? String,
              let clientEmail = json["client_email"] as? String,
              let tokenURI = json["token_uri"] as? String else {
            throw SheetError.invalidServiceAccount
        }
        
        // Create JWT
        struct MyClaims: Claims {
            let iss: String
            let scope: String
            let aud: String
            let exp: Date
            let iat: Date
        }
        
        let now = Date()
        let exp = now.addingTimeInterval(3600) // 1 hour
        let claims = MyClaims(
            iss: clientEmail,
            scope: "https://www.googleapis.com/auth/spreadsheets",
            aud: tokenURI,
            exp: exp,
            iat: now
        )
        
        var jwt = JWT(claims: claims)
        let jwtSigner = JWTSigner.rs256(privateKey: Data(privateKeyPEM.utf8))
        let signedJWT = try jwt.sign(using: jwtSigner)
        
        // Exchange JWT for Access Token
        var request = URLRequest(url: URL(string: tokenURI)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyComponents = [
            "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion=\(signedJWT)"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        
        guard let responseJSON = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let newToken = responseJSON["access_token"] as? String else {
            throw SheetError.authFailed
        }
        
        self.accessToken = newToken
        self.tokenExpiration = exp
        return newToken
    }
}

public enum SheetError: Error {
    case invalidServiceAccount
    case authFailed
    case apiError(String)
}
