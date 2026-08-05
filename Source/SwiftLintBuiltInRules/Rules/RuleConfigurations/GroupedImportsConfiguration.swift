import SwiftLintCore

@AutoConfigParser
struct GroupedImportsConfiguration: SeverityBasedRuleConfiguration {
    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)

    /// The project's own modules, which sort between Apple's frameworks and third-party ones.
    @ConfigurationElement(key: "our_modules")
    private(set) var ourModules = Set<String>()
}
