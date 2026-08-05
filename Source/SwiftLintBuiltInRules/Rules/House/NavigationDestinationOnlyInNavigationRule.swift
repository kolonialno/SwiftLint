import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NavigationDestinationOnlyInNavigationRule: Rule { // swiftlint:disable:this type_name
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "navigation_destination_only_in_navigation",
        name: "Navigation Destination Only In Navigation",
        description: """
            Register destinations in the Navigation folder and route through Navigator; a local routing table \
            is a screen the navigator cannot reach
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "view.navigationDestination(isPresented: $isShown) { Detail() }",
            "navigator.register(Destination.product.self)",
        ]),
        triggeringExamples: #examples([
            "view↓.navigationDestination(for: ProductRecord.self) { Detail(record: $0) }",
            """
                view
                    ↓.navigationDestination(
                        for: Discount.self
                    ) { Detail(discount: $0) }
                """,
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NavigationDestinationOnlyInNavigationRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard node.calledMemberName == "navigationDestination",
                node.firstArgumentLabel == "for",
                let position = node.calledMemberPeriodPosition
            else {
                return
            }
            violations.append(position)
        }
    }
}
