import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoDirectPresentationRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_direct_presentation",
        name: "No Direct Presentation",
        description: """
            Present app-visible content through the navigator; SwiftUI's own presentation belongs to the \
            navigation layer that implements it
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "struct Screen: View { var body: some View { Text(\"hi\") } }",
            """
                struct Screen: View {
                    let finished: () -> Void
                    var body: some View { Button("Done", action: finished) }
                }
                """,
            "@Environment(\\.kolibriTheme) private var theme",
            "view.popover(attachmentAnchor: anchor) { Text(\"hi\") }",
        ]),
        triggeringExamples: #examples([
            "struct Screen: View { ↓@Environment(\\.dismiss) private var dismiss }",
            "struct Screen: View { ↓@Environment(\\.presentationMode) var presentationMode }",
            "view↓.sheet(isPresented: $isShown) { Detail() }",
            "view↓.fullScreenCover(isPresented: $isShown) { Detail() }",
            "view↓.popover(isPresented: $isShown) { Detail() }",
            "view↓.sheet(item: $selected) { Detail(item: $0) }",
            """
                view
                    ↓.sheet(
                        isPresented: $isShown
                    ) { Detail() }
                """,
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoDirectPresentationRule {
    /// A presentation modifier bound to state rather than to content, which is the navigator's job.
    static let modifiers: Set<String> = ["sheet", "fullScreenCover", "popover"]
    static let stateLabels: Set<String> = ["isPresented", "item"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: AttributeSyntax) {
            guard let key = node.environmentKeyRead, key == "dismiss" || key == "presentationMode" else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }

        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard let name = node.calledMemberName,
                NoDirectPresentationRule.modifiers.contains(name),
                let label = node.firstArgumentLabel,
                NoDirectPresentationRule.stateLabels.contains(label),
                let position = node.calledMemberPeriodPosition
            else {
                return
            }
            violations.append(position)
        }
    }
}
