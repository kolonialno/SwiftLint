import SwiftLintCore

@AutoConfigParser
struct MultilineConditionsConfiguration: SeverityBasedRuleConfiguration {
    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)

    @ConfigurationElement(key: "allows_single_line")
    private(set) var allowsSingleLine = true

    @ConfigurationElement(key: "max_number_of_single_line_parameters")
    private(set) var maxNumberOfSingleLineParameters: Int?

    @ConfigurationElement(key: "requires_single_line")
    private(set) var requiresSingleLine = false

    func validate() throws(Issue) {
        if requiresSingleLine, !allowsSingleLine {
            throw Issue.inconsistentConfiguration(
                ruleID: Parent.identifier,
                message: """
                         Option '\($requiresSingleLine.key)' cannot be true when \
                         '\($allowsSingleLine.key)' is false
                         """
            )
        }

        guard let maxNumberOfSingleLineParameters else { return }

        guard maxNumberOfSingleLineParameters >= 1 else {
            throw Issue.inconsistentConfiguration(
                ruleID: Parent.identifier,
                message: "Option '\($maxNumberOfSingleLineParameters.key)' should be >= 1."
            )
        }

        if maxNumberOfSingleLineParameters > 1, !allowsSingleLine {
            throw Issue.inconsistentConfiguration(
                ruleID: Parent.identifier,
                message: """
                         Option '\($maxNumberOfSingleLineParameters.key)' has no effect when \
                         '\($allowsSingleLine.key)' is false
                         """
            )
        }
    }
}
