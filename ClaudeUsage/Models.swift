import Foundation

/// A single usage window (e.g. the 5-hour or 7-day limit) returned by the
/// Anthropic OAuth usage endpoint.
struct UsageWindow: Decodable {
    let utilization: Double
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

/// Pay-as-you-go "extra usage" block. All fields are null when disabled.
struct ExtraUsage: Decodable {
    let isEnabled: Bool?
    let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case utilization
    }
}

/// Full response of `GET https://api.anthropic.com/api/oauth/usage`.
struct UsageResponse: Decodable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDayOpus: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }
}

extension JSONDecoder {
    /// Decoder that tolerates `resets_at` values both with and without
    /// fractional seconds (the API mixes the two forms across fields).
    static func anthropic() -> JSONDecoder {
        let decoder = JSONDecoder()

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { innerDecoder in
            let raw = try innerDecoder.singleValueContainer().decode(String.self)
            if let date = withFractional.date(from: raw) ?? withoutFractional.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: innerDecoder.codingPath,
                      debugDescription: "Unrecognized date format: \(raw)")
            )
        }
        return decoder
    }
}

extension Date {
    /// Human-friendly countdown until this date, e.g. "2h 14m".
    /// Returns "now" when the date is in the past.
    func resetCountdown(from reference: Date = Date()) -> String {
        let seconds = Int(timeIntervalSince(reference))
        guard seconds > 0 else { return "now" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "1m"
    }
}
