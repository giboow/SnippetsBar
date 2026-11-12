import XCTest

/// Every translation must have exactly the English keys, with the same format specifiers.
final class LocalizationTests: XCTestCase {
    private let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Localization")

    private func strings(_ language: String) throws -> [String: String] {
        let url = directory.appendingPathComponent("\(language).lproj/Localizable.strings")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try XCTUnwrap(plist as? [String: String], "\(language): invalid .strings file")
    }

    private func specifiers(_ string: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(lld|@|d)")
        return regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            .map { (string as NSString).substring(with: $0.range) }
    }

    func testTranslationsMatchEnglish() throws {
        let english = try strings("en")
        XCTAssertFalse(english.isEmpty)
        let languages = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".lproj") && $0 != "en.lproj" }
            .map { String($0.dropLast(".lproj".count)) }
        XCTAssertEqual(Set(languages), ["fr", "es", "it", "de", "pt-BR", "ja", "zh-Hans"])

        for language in languages {
            let translated = try strings(language)
            XCTAssertEqual(Set(translated.keys), Set(english.keys), "\(language): keys differ from English")
            for (key, value) in translated {
                XCTAssertFalse(value.isEmpty, "\(language): empty translation for “\(key)”")
                XCTAssertEqual(specifiers(value), specifiers(key), "\(language): format specifiers differ for “\(key)”")
            }
        }
    }
}
