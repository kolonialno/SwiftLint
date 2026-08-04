import Foundation
import SwiftLintCore

/// The paths a rule applies to, for rules that apply to some of a project rather than all of it.
///
/// `included`/`excluded` in a configuration file scope the *run*, and are a feature of custom rules only —
/// a built-in rule is handed every file the linter opens. A rule that encodes an architectural boundary
/// needs the boundary itself: "no direct presentation, except inside the navigation layer that implements
/// it". So the scope travels with the rule and the rule asks before reporting.
struct FileScope: Equatable, Sendable {
    /// A regular expression a file's path must match for the rule to apply. `nil` means every path.
    private(set) var included: String?

    /// A regular expression that exempts a matching path, applied after `included`.
    private(set) var excluded: String?

    /// Whether the rule applies to this file.
    ///
    /// A file with no path — a snippet linted from stdin, or an example in a rule's own test suite — is in
    /// scope, since excluding it would make every scoped rule untestable.
    func contains(_ file: SwiftLintFile) -> Bool {
        guard let path = file.path?.relativePath else {
            return true
        }
        if let included, !matches(included, path) {
            return false
        }
        if let excluded, matches(excluded, path) {
            return false
        }
        return true
    }

    private func matches(_ pattern: String, _ path: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // A pattern that does not compile is a configuration error, not a licence to stop linting.
            return false
        }
        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }
}
