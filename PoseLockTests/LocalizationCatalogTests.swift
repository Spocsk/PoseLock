import XCTest
@testable import PoseLock

/// Le français est la langue source des catalogues, l'anglais la langue de repli
/// du bundle. Une clé oubliée ne casse pas la compilation : elle s'affiche en
/// français au milieu d'un écran allemand. Ces tests lisent les tables compilées
/// dans l'app, pas les `.xcstrings`, donc ce que l'utilisateur verra vraiment.
final class LocalizationCatalogTests: XCTestCase {
    private static let translated = ["en", "es", "de", "pt-BR"]
    private static let tables = ["Localizable", "Cues", "InfoPlist"]

    func testEveryLanguageCoversEveryFrenchKey() throws {
        for table in Self.tables {
            let source = try strings(table, "fr")
            XCTAssertFalse(source.isEmpty, "fr.lproj/\(table).strings vide : l'app retomberait sur l'anglais")
            for language in Self.translated {
                let target = try strings(table, language)
                let missing = Set(source.keys).subtracting(target.keys)
                XCTAssertTrue(missing.isEmpty, "\(language)/\(table) : \(missing.sorted())")
            }
        }
    }

    func testTranslationsKeepTheSourceFormatSpecifiers() throws {
        for table in Self.tables {
            let source = try strings(table, "fr")
            for language in Self.translated {
                for (key, value) in try strings(table, language) {
                    XCTAssertEqual(
                        specifiers(in: value), specifiers(in: source[key] ?? key),
                        "\(language)/\(table) : « \(value) »"
                    )
                }
            }
        }
    }

    func testEveryCueAndItsMirrorIsTranslated() throws {
        for language in Self.translated {
            let bundle = try lproj(language)
            for pose in PoseID.allCases {
                let template = TemplateLibrary.template(for: pose)
                for cue in (template.features + template.mirrored.features).map(\.cue) {
                    XCTAssertNotEqual(
                        CueText.localized(cue, bundle: bundle), cue,
                        "\(language) : cue « \(cue) » (\(pose.rawValue)) sans traduction"
                    )
                }
            }
            XCTAssertNotEqual(CueText.localized("Tiens la ligne.", bundle: bundle), "Tiens la ligne.")
        }
    }

    func testPeriodPluralsFollowEachLanguage() throws {
        let cases: [(String, Int, String)] = [
            ("fr", 1, "1 semaine"), ("fr", 2, "2 semaines"),
            ("en", 1, "1 week"), ("en", 3, "3 weeks"),
            ("de", 1, "1 Woche"), ("de", 2, "2 Wochen"),
            ("es", 1, "1 semana"), ("pt-BR", 2, "2 semanas")
        ]
        for (language, value, expected) in cases {
            let label = String(
                localized: "\(value) semaines",
                bundle: try lproj(language),
                locale: Locale(identifier: language)
            )
            XCTAssertEqual(label, expected, language)
        }
    }

    // MARK: - Helpers

    private func lproj(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"), "\(language).lproj absent")
        return try XCTUnwrap(Bundle(path: path))
    }

    /// Table compilée, plus les clés plurielles du `.stringsdict` (valeur = clé).
    private func strings(_ table: String, _ language: String) throws -> [String: String] {
        let bundle = try lproj(language)
        var result: [String: String] = [:]
        if let url = bundle.url(forResource: table, withExtension: "strings"),
           let dictionary = NSDictionary(contentsOf: url) as? [String: String] {
            result.merge(dictionary) { current, _ in current }
        }
        if let url = bundle.url(forResource: table, withExtension: "stringsdict"),
           let dictionary = NSDictionary(contentsOf: url) as? [String: Any] {
            for key in dictionary.keys where result[key] == nil { result[key] = key }
        }
        return result
    }

    /// Types des arguments, sans les positions : « %1$@ » et « %@ » se valent.
    private func specifiers(in text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(lld|ld|d|@|f)")
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range)
            .compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
            .sorted()
    }
}
