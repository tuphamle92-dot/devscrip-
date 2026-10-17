import Foundation

enum L10n {
    static var language: String {
        get { UserDefaults.standard.string(forKey: "MugoatLanguage") == "en" ? "en" : "vi" }
        set { UserDefaults.standard.set(newValue == "en" ? "en" : "vi", forKey: "MugoatLanguage") }
    }
    static let translations: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "Localizations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return values
    }()
    static func text(_ source: String) -> String {
        let selected = language
        if let value = translations[source]?[selected] { return value }
        // Dynamic status lines retain filenames, sizes and interpolation values;
        // translate their surrounding known phrases without changing those data.
        var result = source
        for key in phraseKeys {
            if result.contains(key), let value = translations[key]?[selected], key != value { result = result.replacingOccurrences(of: key, with: value) }
        }
        return result
    }
    private static let phraseKeys = translations.keys.filter { $0.count >= 12 }.sorted { $0.count > $1.count }
}
