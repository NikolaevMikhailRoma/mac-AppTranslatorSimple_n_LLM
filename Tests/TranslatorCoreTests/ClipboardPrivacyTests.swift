import XCTest
@testable import TranslatorCore

final class ClipboardPrivacyTests: XCTestCase {
    func testPasswordManagerTypesArePrivate() {
        XCTAssertTrue(ClipboardPrivacy.isPrivate(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        XCTAssertTrue(ClipboardPrivacy.isPrivate(types: ["org.nspasteboard.TransientType"]))
    }

    func testOrdinaryTextIsNot() {
        XCTAssertFalse(ClipboardPrivacy.isPrivate(types: ["public.utf8-plain-text", "NSStringPboardType"]))
        XCTAssertFalse(ClipboardPrivacy.isPrivate(types: []))
    }
}
