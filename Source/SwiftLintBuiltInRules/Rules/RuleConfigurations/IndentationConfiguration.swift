import SwiftLintCore

@AutoConfigParser
struct IndentationConfiguration: SeverityBasedRuleConfiguration {
    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)

    @ConfigurationElement(key: "width")
    private(set) var width = 4
}
