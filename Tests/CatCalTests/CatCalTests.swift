import Testing
@testable import CatCal

@Suite("Bootstrap")
struct BootstrapTests {
    @Test("Project builds and links the test target")
    func projectBuilds() {
        #expect(true)
    }
}
