import SwiftLintCore
import SwiftSyntax
import SwiftSyntaxBuilder

@SwiftSyntaxRule(explicitRewriter: true, optIn: true)
struct KeyPathOnlyWhereTheAPITakesOneRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "key_path_only_where_the_api_takes_one",
        name: "Key Path Only Where The API Takes One",
        description: """
            Pass a closure. A key path is for an API whose parameter really is a KeyPath, so spending `\\.` as \
            closure shorthand costs the reader that signal
            """,
        kind: .idiomatic,
        nonTriggeringExamples: #examples([
            "products.map { $0.name }",
            "products.filter { $0.isAvailable }",
            "products.removingDuplicates(by: \\.id)",
            "view.environment(\\.theme, theme)",
            "node.with(\\.leadingTrivia, trivia)",
            "products.map(\\Product.name)",
            "products.reduce(into: [:]) { $0[$1.id] = $1 }",
        ]),
        triggeringExamples: #examples([
            "products.map(↓\\.name)",
            "products.compactMap(↓\\.discount)",
            "products.filter(↓\\.isAvailable)",
            "products.allSatisfy(↓\\.isAvailable)",
            "products.contains(where: ↓\\.isAvailable)",
            "products.first(where: ↓\\.isAvailable)",
            "products.prefix(while: ↓\\.isAvailable)",
            "products.map(↓\\.price.amount)",
            "products.last(where: ↓\\.isAvailable)",
            "products.firstIndex(where: ↓\\.isAvailable)",
            "products.removeAll(where: ↓\\.isDiscontinued)",
        ]),
        corrections: #corrections([
            "products.map(\\.name)": "products.map { $0.name }",
            "products.filter(\\.isAvailable)": "products.filter { $0.isAvailable }",
            "products.contains(where: \\.isAvailable)": "products.contains(where: { $0.isAvailable })",
            "products.first(where: \\.isAvailable)": "products.first(where: { $0.isAvailable })",
            "products.map(\\.price.amount)": "products.map { $0.price.amount }",
            "names.map(\\.count).filter(\\.isMultiple)":
                "names.map { $0.count }.filter { $0.isMultiple }",
            "if products.allSatisfy(\\.isAvailable) { pay() }":
                "if products.allSatisfy({ $0.isAvailable }) { pay() }",
            "guard products.allSatisfy(\\.isAvailable) else { return }":
                "guard products.allSatisfy({ $0.isAvailable }) else { return }",
        ])
    )
}

private extension SyntaxProtocol {
    /// Whether this sits in an `if`/`guard`/`while` condition, where Swift rejects a trailing closure.
    var isInACondition: Bool {
        ancestorOrSelf { $0.as(ConditionElementSyntax.self) } != nil
    }
}

private extension KeyPathOnlyWhereTheAPITakesOneRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard let keyPath = node.coercedKeyPath else {
                return
            }
            violations.append(keyPath.positionAfterSkippingLeadingTrivia)
        }
    }

    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
            guard let keyPath = node.coercedKeyPath,
                let argument = node.arguments.onlyElement
            else {
                return super.visit(node)
            }
            let body = ExprSyntax("{ $0\(raw: keyPath.components.trimmedDescription) }")
            numberOfCorrections += 1
            // A trailing closure is the house form, but it cannot sit in a condition — `if xs.allSatisfy { … } {`
            // does not parse — and a labelled argument reads better keeping its label, which is what the
            // repository's own `first(where:)` and `contains(where:)` call sites do.
            guard argument.label == nil,
                !node.isInACondition,
                let closure = body.as(ClosureExprSyntax.self)
            else {
                let parenthesised = node.with(
                    \.arguments,
                    LabeledExprListSyntax([argument.with(\.expression, body)]))
                return super.visit(parenthesised)
            }
            // The closing paren's trailing trivia is the space before whatever follows the call —
            // `?? []`, a closing brace — so the closure inherits it or the two run together.
            let trailing = node
                .with(\.leftParen, nil)
                .with(\.arguments, [])
                .with(\.rightParen, nil)
                .with(
                    \.trailingClosure,
                    closure
                        .with(\.leadingTrivia, .space)
                        .with(\.trailingTrivia, node.rightParen?.trailingTrivia ?? []))
            return super.visit(trailing)
        }
    }
}
