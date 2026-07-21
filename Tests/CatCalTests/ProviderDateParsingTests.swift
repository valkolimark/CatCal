import Foundation
import Testing
@testable import CatCal

private let utc = TimeZone(secondsFromGMT: 0)!

private func components(_ date: Date, in timeZone: TimeZone = utc) -> DateComponents {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
}

@Suite("Google date parsing")
struct GoogleDateParsingTests {
    @Test("Parses an RFC 3339 timestamp with an offset")
    func timedEvent() throws {
        let date = try #require(
            ProviderDateParsing.googleDate(dateTime: "2026-07-19T09:00:00-05:00", date: nil)
        )
        let parts = components(date)

        #expect(parts.hour == 14)
        #expect(parts.day == 19)
    }

    @Test("Parses a timestamp that carries fractional seconds")
    func fractionalSeconds() throws {
        let date = try #require(
            ProviderDateParsing.googleDate(dateTime: "2026-07-19T09:00:00.000Z", date: nil)
        )
        #expect(components(date).hour == 9)
    }

    @Test("An all-day date resolves to midnight in the given zone, not UTC")
    func allDayUsesLocalZone() throws {
        let chicago = try #require(TimeZone(identifier: "America/Chicago"))
        let date = try #require(
            ProviderDateParsing.googleDate(dateTime: nil, date: "2026-07-19", timeZone: chicago)
        )
        let parts = components(date, in: chicago)

        // The point of resolving in the device's zone: an all-day event on the
        // 19th must still read as the 19th, not slip to the 18th.
        #expect(parts.day == 19)
        #expect(parts.hour == 0)
    }

    @Test("Neither field present yields nil rather than a bogus date")
    func missingFields() {
        #expect(ProviderDateParsing.googleDate(dateTime: nil, date: nil) == nil)
    }

    @Test("Garbage in a date field yields nil")
    func unparseable() {
        #expect(ProviderDateParsing.googleDate(dateTime: "not a date", date: nil) == nil)
    }
}

@Suite("Microsoft Graph date parsing")
struct GraphDateParsingTests {
    @Test("Recombines a zone-less time with its named time zone")
    func namedTimeZone() throws {
        let date = try #require(
            ProviderDateParsing.graphDate(dateTime: "2026-07-19T09:00:00.0000000", timeZone: "America/Chicago")
        )
        // 09:00 in Chicago (CDT, UTC-5) is 14:00 UTC.
        #expect(components(date).hour == 14)
    }

    @Test("Trims Graph's seven fractional digits rather than failing on them")
    func sevenFractionalDigits() throws {
        let date = try #require(
            ProviderDateParsing.graphDate(dateTime: "2026-07-19T15:30:00.1234567", timeZone: "UTC")
        )
        let parts = components(date)

        #expect(parts.hour == 15)
        #expect(parts.minute == 30)
    }

    @Test("A missing time zone falls back to UTC, matching the Prefer header we send")
    func missingTimeZoneIsUTC() throws {
        let date = try #require(
            ProviderDateParsing.graphDate(dateTime: "2026-07-19T09:00:00.0000000", timeZone: nil)
        )
        #expect(components(date).hour == 9)
    }

    @Test("An unrecognized time zone name falls back to UTC instead of nil")
    func unknownTimeZoneIsUTC() throws {
        let date = try #require(
            ProviderDateParsing.graphDate(dateTime: "2026-07-19T09:00:00", timeZone: "Not/AZone")
        )
        #expect(components(date).hour == 9)
    }

    @Test("A missing dateTime yields nil")
    func missingDateTime() {
        #expect(ProviderDateParsing.graphDate(dateTime: nil, timeZone: "UTC") == nil)
    }
}
