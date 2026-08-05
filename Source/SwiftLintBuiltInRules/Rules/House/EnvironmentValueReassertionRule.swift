import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct EnvironmentValueReassertionRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "environment_value_reassertion",
        name: "Environment Value Reassertion",
        description: """
            Re-injecting a value this view already reads from the environment means it isn't context — pass it \
            explicitly to the views that need it
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            """
                struct Screen: View {
                    @Environment(\\.theme) private var theme
                    var body: some View { Text("hi").foregroundStyle(theme.accent) }
                }
                """,
            """
                struct Screen: View {
                    @Environment(\\.theme) private var theme
                    var body: some View { Sheet().environment(\\.locale, locale) }
                }
                """,
            """
                struct Root: View {
                    var body: some View { Screen().environment(\\.theme, .oda) }
                }
                """,
        ]),
        triggeringExamples: #examples([
            """
                struct Screen: View {
                    ↓@Environment(\\.theme) private var theme
                    var body: some View {
                        Sheet().environment(\\.theme, theme)
                    }
                }
                """,
            """
                struct Screen: View {
                    ↓@Environment(\\.theme) private var theme: Theme
                    var body: some View {
                        bar.safeAreaInset(edge: .bottom) { Bar().environment(\\.theme, theme) }
                    }
                }
                """,
        ])
    )
}

private extension EnvironmentValueReassertionRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private var reads: [(key: String, position: AbsolutePosition)] = []
        private var injectedKeys: [(key: String, position: AbsolutePosition)] = []

        override func visitPost(_ node: AttributeSyntax) {
            guard let key = node.environmentKeyRead else {
                return
            }
            reads.append((key, node.positionAfterSkippingLeadingTrivia))
        }

        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard let key = node.environmentKeyWritten else {
                return
            }
            injectedKeys.append((key, node.positionAfterSkippingLeadingTrivia))
        }

        override func visitPost(_: SourceFileSyntax) {
            for read in reads
            where injectedKeys.contains(where: { $0.key == read.key && $0.position > read.position }) {
                violations.append(read.position)
            }
        }
    }
}
