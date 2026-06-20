import XCTest
@testable import LearningKit

final class ContentLibraryTests: XCTestCase {
    let lib = ContentLibrary.standard

    func testFixedCastResolves() {
        for id in ContentLibrary.castIDs {
            XCTAssertTrue(lib.hasPicture(id), "cast picture \(id) should exist")
        }
    }

    func testDecodableAndGlue() {
        XCTAssertTrue(lib.isDecodable("cat"))
        XCTAssertTrue(lib.isDecodable("Mat!"))           // normalized
        XCTAssertFalse(lib.isDecodable("the"))           // glue, not decodable
        XCTAssertTrue(lib.isGlue("the"))
        XCTAssertFalse(lib.isGlue("cat"))
    }

    func testSpeakableRules() {
        XCTAssertTrue(lib.isSpeakable("cat", glue: false))
        XCTAssertFalse(lib.isSpeakable("cat", glue: true))   // marked glue but isn't one
        XCTAssertTrue(lib.isSpeakable("the", glue: true))
        XCTAssertFalse(lib.isSpeakable("xyzzy", glue: false))
        XCTAssertFalse(lib.isSpeakable("", glue: false))
    }

    func testNormalize() {
        XCTAssertEqual(ContentLibrary.normalize("Cat."), "cat")
        XCTAssertEqual(ContentLibrary.normalize("MUD!"), "mud")
    }

    func testPictureKindFiltering() {
        XCTAssertNotNil(lib.picture("cat"))
        XCTAssertNil(lib.picture("not-a-thing"))
    }
}
