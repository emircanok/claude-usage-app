import Foundation

enum TokenRefreshError: Error {
    case http(Int)
    case noAccessToken
    case transport(Error)
}

struct RefreshedToken {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Double // epoch milliseconds
}

/// Refreshes an expired Claude OAuth access token using the long-lived refresh
/// token, mirroring how Claude Code itself refreshes. Parameters verified
/// against a reference implementation that coexists with Claude Code.
enum TokenRefresher {
    static let tokenURL = URL(string: "https://claude.ai/v1/oauth/token")!
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// Default lifetime if the server omits `expires_in` (observed ~10h).
    private static let defaultLifetimeSeconds: Double = 36_000

    private struct Response: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let expiresIn: Double?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    static func refresh(refreshToken: String, now: Date = Date()) async throws -> RefreshedToken {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TokenRefreshError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw TokenRefreshError.http(-1)
        }
        guard http.statusCode == 200 else {
            throw TokenRefreshError.http(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let access = decoded.accessToken else {
            throw TokenRefreshError.noAccessToken
        }

        let lifetime = (decoded.expiresIn ?? defaultLifetimeSeconds) * 1000
        return RefreshedToken(
            accessToken: access,
            refreshToken: decoded.refreshToken ?? refreshToken, // keep old if not rotated
            expiresAt: now.timeIntervalSince1970 * 1000 + lifetime
        )
    }
}
