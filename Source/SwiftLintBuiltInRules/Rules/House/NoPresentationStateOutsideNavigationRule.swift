import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoPresentationStateOutsideNavigationRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_presentation_state_outside_navigation",
        name: "No Presentation State Outside Navigation",
        description: """
            Report finishing with a closure and let the navigation folder dismiss; a view must not carry \
            presentation state
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "struct Screen: View { let finished: () -> Void }",
            "struct Screen: View { @Binding var quantity: Int }",
            "struct Screen: View { @Binding var isEnabled: Bool }",
            "struct Screen: View { @State private var isShown = false }",
            "struct Screen: View { var isShown: Bool }",
        ]),
        triggeringExamples: #examples([
            "struct Screen: View { ↓@Binding var isShown: Bool }",
            "struct Screen: View { ↓@Binding var isPresented: Bool }",
            "struct Screen: View { ↓@Binding public var isShown: Bool }",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoPresentationStateOutsideNavigationRule {
    static let names: Set<String> = ["isShown", "isPresented"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: VariableDeclSyntax) {
            guard node.attributes.contains(attributeNamed: "Binding"),
                let binding = node.bindings.onlyElement,
                let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                NoPresentationStateOutsideNavigationRule.names.contains(name),
                binding.typeAnnotation?.type.trimmedDescription == "Bool"
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
