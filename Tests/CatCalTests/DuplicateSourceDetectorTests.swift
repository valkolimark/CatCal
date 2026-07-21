import Foundation
import Testing
@testable import CatCal

private func account(_ title: String, kind: CalendarSource = .google, id: String? = nil) -> EventKitAccount {
    EventKitAccount(
        id: id ?? title,
        title: title,
        kind: kind,
        calendars: [SourceCalendar(id: "\(title)-cal", title: "Calendar", accountEmail: title)]
    )
}

@Suite("Duplicate source detection")
struct DuplicateSourceDetectorTests {
    @Test("Matches an EventKit account whose title is the same address")
    func exactAddressMatch() {
        let accounts = [account("iCloud", kind: .iCloud), account("mark@gmail.com")]

        let match = DuplicateSourceDetector.account(
            matching: "mark@gmail.com",
            in: accounts,
            provider: .google
        )

        #expect(match?.title == "mark@gmail.com")
    }

    @Test("Matching ignores case and surrounding whitespace")
    func caseInsensitive() {
        let accounts = [account("Mark@Gmail.com")]

        let match = DuplicateSourceDetector.account(
            matching: "  MARK@gmail.COM ",
            in: accounts,
            provider: .google
        )

        #expect(match != nil)
    }

    @Test("Matches when the address is embedded in a longer account title")
    func containedAddress() {
        let accounts = [account("Google (mark@gmail.com)")]

        let match = DuplicateSourceDetector.account(
            matching: "mark@gmail.com",
            in: accounts,
            provider: .google
        )

        #expect(match?.title == "Google (mark@gmail.com)")
    }

    @Test("Matches on the local part when the account is tagged as the same provider")
    func localPartWithMatchingProvider() {
        let accounts = [account("mark - Gmail", kind: .google)]

        let match = DuplicateSourceDetector.account(
            matching: "mark@gmail.com",
            in: accounts,
            provider: .google
        )

        #expect(match != nil)
    }

    @Test("A same-named account under a different provider is not a duplicate")
    func differentProviderIsNotADuplicate() {
        // The weak local-part match must not fire across providers: an
        // Exchange mailbox called "mark" has nothing to do with a Google
        // account, and a false warning that hides calendars is worse than no
        // warning at all.
        let accounts = [account("mark - Exchange", kind: .outlook)]

        let match = DuplicateSourceDetector.account(
            matching: "mark@gmail.com",
            in: accounts,
            provider: .google
        )

        #expect(match == nil)
    }

    @Test("A generic iCloud account never matches a Google address")
    func iCloudIsNotADuplicate() {
        let accounts = [account("iCloud", kind: .iCloud)]

        let match = DuplicateSourceDetector.account(
            matching: "mark@gmail.com",
            in: accounts,
            provider: .google
        )

        #expect(match == nil)
    }

    @Test("A very short local part doesn't match on its own")
    func shortLocalPartIsIgnored() {
        // "jo" appearing anywhere in an account title would match far too
        // much, so the weak path requires at least three characters.
        let accounts = [account("Johnson Family Calendar", kind: .google)]

        let match = DuplicateSourceDetector.account(
            matching: "jo@gmail.com",
            in: accounts,
            provider: .google
        )

        #expect(match == nil)
    }

    @Test("Matches on the domain for work accounts titled by company")
    func domainMatch() {
        let accounts = [account("contoso.com", kind: .outlook)]

        let match = DuplicateSourceDetector.account(
            matching: "mark@contoso.com",
            in: accounts,
            provider: .microsoft
        )

        #expect(match?.title == "contoso.com")
    }

    @Test("An empty email matches nothing")
    func emptyEmail() {
        #expect(
            DuplicateSourceDetector.account(matching: "", in: [account("iCloud")], provider: .google) == nil
        )
    }

    @Test("No EventKit accounts means nothing to duplicate")
    func noAccounts() {
        #expect(
            DuplicateSourceDetector.account(matching: "mark@gmail.com", in: [], provider: .google) == nil
        )
    }

    @Test("An exact match wins over a weaker candidate listed first")
    func exactMatchWinsOverWeakOne() {
        let accounts = [account("mark - Gmail", kind: .google), account("mark@gmail.com", kind: .google)]

        let match = DuplicateSourceDetector.account(
            matching: "mark@gmail.com",
            in: accounts,
            provider: .google
        )

        #expect(match?.title == "mark@gmail.com")
    }
}
