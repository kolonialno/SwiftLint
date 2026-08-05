import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct EnvironmentKeyNeedsJudgementRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "environment_key_needs_judgement",
        name: "Environment Key Needs Judgement",
        description: """
            A new environment key needs a branch that reads a different value than its parent, and a default \
            that is the real ambient behaviour. Otherwise inject it at init
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "struct Theme { let accent: Color }",
            "final class Session: ObservableObject {}",
            "extension EnvironmentValues { var theme: Theme { self[ThemeKey.self] } }",
        ]),
        triggeringExamples: #examples([
            "struct ThemeKey↓: EnvironmentKey { static let defaultValue = Theme.oda }",
            "struct ThemeKey↓: Sendable, EnvironmentKey { static let defaultValue = Theme.oda }",
            "extension EnvironmentValues { ↓@Entry var theme = Theme.oda }",
        ])
    )
}

private extension EnvironmentKeyNeedsJudgementRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: InheritanceClauseSyntax) {
            guard node.inheritedTypes.contains(where: { $0.type.trimmedDescription == "EnvironmentKey" }) else {
                return
            }
            violations.append(node.colon.positionAfterSkippingLeadingTrivia)
        }

        override func visitPost(_ node: AttributeSyntax) {
            guard node.attributeName.trimmedDescription == "Entry" else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
