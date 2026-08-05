import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct ValueStorageBuiltOnlyAtTheRootRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "value_storage_built_only_at_the_root",
        name: "Value Storage Built Only At The Root",
        description: """
            Take the storage the composition root hands you; only an entry point names the store it persists \
            to, and a double names itself
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "let storage: any ValueStoring",
            "ValueStorage(name: .preview)",
            "ValueStorage(name: .test)",
            "ValueStorage(name: .preview(#file))",
            "ValueStorage()",
        ]),
        triggeringExamples: #examples([
            "let storage = ↓ValueStorage(name: .tienda)",
            "Screen(storage: ↓ValueStorage(name: chosen))",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension ValueStorageBuiltOnlyAtTheRootRule {
    /// Named by what is allowed rather than by the real store, so naming it through a variable cannot walk past.
    static let doubles: Set<String> = ["preview", "test"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "ValueStorage",
                let name = node.arguments.first, name.label?.text == "name",
                !name.expression.namesADouble
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}

private extension ExprSyntax {
    /// `.preview`, `.test`, or either of them called — the shapes a double names itself with.
    var namesADouble: Bool {
        // `as` is a keyword, so the receiver cannot be dropped here.
        // swiftlint:disable:next redundant_self
        let receiver = self.as(FunctionCallExprSyntax.self)?.calledExpression ?? self
        guard let member = receiver.as(MemberAccessExprSyntax.self), member.base == nil else {
            return false
        }
        return ValueStorageBuiltOnlyAtTheRootRule.doubles.contains(member.declName.baseName.text)
    }
}
