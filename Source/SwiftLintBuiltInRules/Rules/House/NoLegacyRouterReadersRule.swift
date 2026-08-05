import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoLegacyRouterReadersRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "no_legacy_router_readers",
        name: "No Legacy Router Readers",
        description: """
            Navigate through an injected navigator; reading the legacy router from the environment resolves \
            to a dead default in a modern stack and silently no-ops
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "let navigator: any Navigating",
            "@Environment(\\.kolibriTheme) private var theme",
        ]),
        triggeringExamples: #examples([
            "struct Screen: View { ↓@Environment(\\.legacyRouter) private var router }",
            "struct Screen: View { ↓@Environment(\\.legacyRouter) var router: LegacyRouter }",
        ])
    )
}

private extension NoLegacyRouterReadersRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: AttributeSyntax) {
            guard node.environmentKeyRead == "legacyRouter" else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
