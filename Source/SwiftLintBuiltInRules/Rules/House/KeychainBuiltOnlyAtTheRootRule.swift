import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct KeychainBuiltOnlyAtTheRootRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "keychain_built_only_at_the_root",
        name: "Keychain Built Only At The Root",
        description: """
            Take the keychain store the entry point hands you; a preview or a test that builds its own reads \
            the real device keychain
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "let keychain: any KeychainStoring",
            "InMemoryKeychain()",
            "MyKeychain()",
            "Keychain(service: \"oda\")",
        ]),
        triggeringExamples: #examples([
            "let store = ↓Keychain()",
            "Session(keychain: ↓Keychain())",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension KeychainBuiltOnlyAtTheRootRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Keychain",
                node.arguments.isEmpty,
                node.trailingClosure == nil
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
