import Foundation

enum UsageClientError: Error {
    case unauthorized
    case http(Int)
    case transport(Error)
}

/// Talks to the unofficial Anthropic OAuth usage endpoint that Claude Code's
/// `/usage` command uses.
struct UsageClient {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// Version reported in the User-Agent. The header is required: without a
    /// `claude-code/...` User-Agent the endpoint serves an aggressively
    /// rate-limited bucket and returns persistent 429s.
    static let appVersion = "2.1.159"

    static func fetch(accessToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("claude-code/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw UsageClientError.http(-1)
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder.anthropic().decode(UsageResponse.self, from: data)
        case 401, 403:
            throw UsageClientError.unauthorized
        default:
            throw UsageClientError.http(http.statusCode)
        }
    }
}
