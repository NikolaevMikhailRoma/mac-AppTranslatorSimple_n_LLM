import XCTest
@testable import LLMTranslatorCore

final class LanguageDetectorTests: XCTestCase {
    private let detector = LanguageDetector(native: "ru", second: "en")

    func testCyrillicTranslatesToLanguage2() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "Привет, мир").target, "en")
    }

    func testLatinTranslatesToLanguage1() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "Hello, world").target, "ru")
    }

    func testAnyNonCyrillicScriptTranslatesToLanguage1() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "你好，世界").target, "ru")
    }

    func testMixedTextFollowsMajority() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "Запусти swift build ещё раз").target, "en")
    }

    func testNoLettersGoesToLanguage2() {
        XCTAssertEqual(detector.determineLanguageDirection(for: "12345").target, "en")
    }

    func testLanguage2IsTheSetting() {
        let german = LanguageDetector(native: "ru", second: "de")
        XCTAssertEqual(german.determineLanguageDirection(for: "Привет").target, "de")
    }
}
