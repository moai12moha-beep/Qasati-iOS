import XCTest
@testable import QasatiApp

final class RefreshSignalTests: XCTestCase {

    func test_initialVersion_isZero() {
        let signal = RefreshSignal()
        XCTAssertEqual(signal.version, 0)
    }

    func test_bump_incrementsVersion() {
        let signal = RefreshSignal()

        signal.bump()
        XCTAssertEqual(signal.version, 1)

        signal.bump()
        XCTAssertEqual(signal.version, 2)
    }

    func test_bump_repeatedCalls_produceStrictlyIncreasingVersions() {
        let signal = RefreshSignal()
        var seen: [Int] = [signal.version]

        for _ in 0..<5 {
            signal.bump()
            seen.append(signal.version)
        }

        XCTAssertEqual(seen, [0, 1, 2, 3, 4, 5])
    }
}
