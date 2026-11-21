import Foundation

/// Localization. English source strings double as keys: every .lproj table maps them to a
/// translation, and a missing key falls back to its English text. Languages ship as
/// <code>.lproj/Localizable.strings inside the bundle's Resources.
enum L10n {
    /// Languages offered under Options → General, shown with their native names.
    /// The order follows the list of most-spoken languages, then additions.
    static let available: [(code: String, name: String)] = [
        ("en", "English"), ("zh-Hans", "简体中文"), ("hi", "हिन्दी"), ("es", "Español"), ("fr", "Français"),
        ("ar", "العربية"), ("bn", "বাংলা"), ("pt", "Português"), ("ru", "Русский"), ("ur", "اردو"),
        ("id", "Bahasa Indonesia"), ("de", "Deutsch"), ("zh-Hant", "繁體中文"), ("ja", "日本語"), ("ko", "한국어"),
    ]
    private static let rtlCodes: Set<String> = ["ar", "ur"]

    private static var cached: (key: String, bundle: Bundle)?

    /// The bundle strings are looked up in. With "system" (the default) Bundle.main follows the
    /// user's preferred languages automatically; otherwise it is the chosen language's .lproj.
    static var bundle: Bundle {
        let key = S.language
        if let cached, cached.key == key { return cached.bundle }
        let resolved: Bundle
        if key != "system", let path = Bundle.main.path(forResource: key, ofType: "lproj"), let b = Bundle(path: path) {
            resolved = b
        } else {
            resolved = .main
        }
        cached = (key, resolved)
        return resolved
    }

    /// The language actually in use, for RTL decisions and diagnostics.
    static var current: String {
        S.language == "system" ? (Bundle.main.preferredLocalizations.first ?? "en") : S.language
    }

    static var isRTL: Bool { rtlCodes.contains(current) }

    static func tr(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), arguments: args)
    }
}
