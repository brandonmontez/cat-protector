import XCTest
@testable import CatProtector

final class ThrottleTests: XCTestCase {
    func testFirstCallIsAllowed() {
        var throttle = Throttle(interval: 1)
        XCTAssertTrue(throttle.allow(at: 100))
    }

    func testCallsInsideIntervalAreDropped() {
        var throttle = Throttle(interval: 1)
        XCTAssertTrue(throttle.allow(at: 100))
        XCTAssertFalse(throttle.allow(at: 100.2))
        XCTAssertFalse(throttle.allow(at: 100.9))
        XCTAssertTrue(throttle.allow(at: 101))
        XCTAssertFalse(throttle.allow(at: 101.5))
    }
}
