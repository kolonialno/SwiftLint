import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoPrintInAppCodeRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_print_in_app_code",
        name: "No Print In App Code",
        description: "Console output is invisible in a shipped build — log through a logger instead",
        kind: .lint,
        nonTriggeringExamples: #examples([
            "logger.info(subsystem: .cart, category: .checkout, message: \"paid\")",
            "let printer = Printer()",
            "receipt.print()",
            "formatter.debugPrint(value)",
        ]),
        triggeringExamples: #examples([
            "↓print(\"here\")",
            "↓debugPrint(response)",
            "if isVerbose { ↓print(request) }",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoPrintInAppCodeRule {
    static let names: Set<String> = ["print", "debugPrint"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
                NoPrintInAppCodeRule.names.contains(name)
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
