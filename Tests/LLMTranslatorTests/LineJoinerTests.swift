import XCTest
@testable import LLMTranslatorCore

final class LineJoinerTests: XCTestCase {
    func testJoinsLinesInsideAParagraph() {
        XCTAssertEqual(LineJoiner.join("Это предложение\nразорвано посередине\nвёрсткой PDF."),
                       "Это предложение разорвано посередине вёрсткой PDF.")
    }

    func testKeepsParagraphs() {
        XCTAssertEqual(LineJoiner.join("First line\nstill first.\n\n\n\nSecond\nparagraph."),
                       "First line still first.\n\nSecond paragraph.")
    }

    func testGluesHyphenatedWord() {
        XCTAssertEqual(LineJoiner.join("экс-\nпорт данных"), "экспорт данных")
        XCTAssertEqual(LineJoiner.join("well-\nknown"), "wellknown")
    }

    func testKeepsHyphenBeforeCapital() {
        XCTAssertEqual(LineJoiner.join("Нью-\nЙорк"), "Нью-Йорк")
    }

    func testKeepsListItems() {
        XCTAssertEqual(LineJoiner.join("Шаги:\n- первый\n- второй\n1. третий\n2) четвёртый"),
                       "Шаги:\n- первый\n- второй\n1. третий\n2) четвёртый")
    }

    func testNormalizesWindowsNewlinesAndSpaces() {
        XCTAssertEqual(LineJoiner.join("  one  \r\n  two  "), "one two")
    }

    func testKeepsBreaksAfterSentences() {
        let message = "Привет! Спасибо за ответ.\nЗавтра пришлю файлы.\n\nПо поводу встречи:\n- в среду не могу\n- в четверг могу после 15:00"
        XCTAssertEqual(LineJoiner.join(message), message)
        XCTAssertEqual(LineJoiner.join("Он сказал «да».\nПотом ушёл"), "Он сказал «да».\nПотом ушёл")
    }

    func testSingleLineUnchanged() {
        XCTAssertEqual(LineJoiner.join("Привет, мир"), "Привет, мир")
    }
}
