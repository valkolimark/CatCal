import Foundation

/// Date parsing for the two calendar APIs, pulled out of their decoders so it
/// can be tested directly. Neither provider sends anything as simple as a
/// plain ISO 8601 instant, and getting either wrong shifts a user's whole day.
enum ProviderDateParsing {
    // MARK: - Google Calendar

    /// Google sends exactly one of `dateTime` (a full RFC 3339 instant, with
    /// or without fractional seconds) or `date` (a bare calendar day, for
    /// all-day events).
    ///
    /// All-day dates carry no zone, so they're resolved in the device's zone:
    /// an all-day event on the 19th should read as the 19th wherever the user
    /// happens to be, not shift a day when they fly east.
    static func googleDate(dateTime: String?, date: String?, timeZone: TimeZone = .current) -> Date? {
        if let dateTime {
            return ISO8601DateFormatter.rfc3339.date(from: dateTime)
                ?? ISO8601DateFormatter.rfc3339WithFractionalSeconds.date(from: dateTime)
        }

        guard let date else { return nil }
        let formatter = DateFormatter.calendarDay
        formatter.timeZone = timeZone
        return formatter.date(from: date)
    }

    // MARK: - Microsoft Graph

    /// Graph sends a zone-*less* local time plus a separate IANA/Windows zone
    /// name, so the two have to be recombined. It also pads to 7 fractional
    /// digits, which `DateFormatter` can't express — those get trimmed rather
    /// than fought with.
    ///
    /// Falls back to UTC when the zone name is missing or unrecognized, which
    /// matches the `Prefer: outlook.timezone="UTC"` header we send.
    static func graphDate(dateTime: String?, timeZone: String?) -> Date? {
        guard let dateTime else { return nil }

        let formatter = DateFormatter.graphLocalDateTime
        formatter.timeZone = timeZone.flatMap(TimeZone.init(identifier:))
            ?? TimeZone(secondsFromGMT: 0)

        return formatter.date(from: trimmingFractionalSeconds(dateTime))
    }

    private static func trimmingFractionalSeconds(_ value: String) -> String {
        guard let dotIndex = value.firstIndex(of: ".") else { return value }
        return String(value[value.startIndex..<dotIndex])
    }
}

/// `nonisolated(unsafe)` on the shared ISO 8601 formatters: they're configured
/// once here and never mutated, and `ISO8601DateFormatter` is documented as
/// safe for concurrent use in that state. The two `DateFormatter`s below are
/// built per call instead, since each one needs its own `timeZone`.
private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let rfc3339: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) static let rfc3339WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static var calendarDay: DateFormatter {
        posix(format: "yyyy-MM-dd")
    }

    static var graphLocalDateTime: DateFormatter {
        posix(format: "yyyy-MM-dd'T'HH:mm:ss")
    }

    private static func posix(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}
