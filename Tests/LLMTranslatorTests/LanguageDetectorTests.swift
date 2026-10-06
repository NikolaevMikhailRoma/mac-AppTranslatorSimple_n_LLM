import XCTest
@testable import LLMTranslatorCore

final class LanguageDetectorTests: XCTestCase {
    private let detector = LanguageDetector(language1: "ru", language2: "en")

    func testCyrillicTranslatesToLanguage2() {
        XCTAssertEqual(detector.direction(for: "Привет, мир").target, "en")
    }

    func testLatinTranslatesToLanguage1() {
        XCTAssertEqual(detector.direction(for: "Hello, world").target, "ru")
    }

    func testAnyNonCyrillicScriptTranslatesToLanguage1() {
        XCTAssertEqual(detector.direction(for: "你好，世界").target, "ru")
    }

    func testMixedTextFollowsMajority() {
        XCTAssertEqual(detector.direction(for: "Запусти swift build ещё раз").target, "en")
    }

    func testNoLettersGoesToLanguage2() {
        XCTAssertEqual(detector.direction(for: "12345").target, "en")
    }

    func testSourceIsKnownOnlyForCyrillic() {
        XCTAssertEqual(detector.direction(for: "Привет").source, "ru")
        XCTAssertNil(detector.direction(for: "Hello").source, "could be any language; the method decides")
    }

    func testLanguage2IsTheSetting() {
        let german = LanguageDetector(language1: "ru", language2: "de")
        XCTAssertEqual(german.direction(for: "Привет").target, "de")
    }
}
