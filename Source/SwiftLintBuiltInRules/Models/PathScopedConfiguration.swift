import SwiftLintCore

/// A severity plus the paths the rule applies to, for a rule that encodes an architectural boundary.
///
/// `included`/`excluded` in a configuration file are a feature of custom rules only, so a built-in rule that
/// applies to part of a project has to carry the boundary itself. Rules using this ask
/// `configuration.scope.contains(file)` from `preprocess(file:)`.
@AutoConfigParser
struct PathScopedConfiguration<Parent: Rule>: SeverityBasedRuleConfiguration {
    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)

    @ConfigurationElement(key: "included")
    private(set) var included: String?

    @ConfigurationElement(key: "excluded")
    private(set) var excluded: String?

    var scope: FileScope {
        FileScope(included: included, excluded: excluded)
    }
}
