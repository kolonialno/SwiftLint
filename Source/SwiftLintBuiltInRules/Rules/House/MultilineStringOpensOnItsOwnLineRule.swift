import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct MultilineStringOpensOnItsOwnLineRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "multiline_string_opens_on_its_own_line",
        name: "Multiline String Opens On Its Own Line",
        description: """
            Open a multi-line string on its own line. Opening it inside a call ties the string's contents to \
            the call's wrapping, so a reformat then edits the value
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            """
            let json =
                \"\"\"
                {"a": 1}
                \"\"\"
            """,
            """
            decode(
                \"\"\"
                {"a": 1}
                \"\"\")
            """,
            "let text = \"one line\"",
            """
            expect(value, \"a plain string\")
            """,
        ]),
        triggeringExamples: #examples([
            """
            decode(↓\"\"\"
                {"a": 1}
                \"\"\")
            """,
            """
            XCTAssertEqual(payload, ↓\"\"\"
                {"a": 1}
                \"\"\")
            """,
            """
            decode(from: ↓#\"\"\"
                {"a": 1}
                \"\"\"#)
            """,
        ])
    )
}

private extension MultilineStringOpensOnItsOwnLineRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: StringLiteralExprSyntax) {
            guard node.openingQuote.tokenKind == .multilineStringQuote,
                node.opensOnALineHoldingAnUnclosedParenthesis
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}

private extension StringLiteralExprSyntax {
    /// Whether a `(` sits on the same line, before the literal — the shape a reindent can silently edit.
    var opensOnALineHoldingAnUnclosedParenthesis: Bool {
        var token: TokenSyntax? = firstToken(viewMode: .sourceAccurate)
        while let current = token {
            if current.leadingTrivia.containsNewline {
                return false
            }
            guard let previous = current.previousToken(viewMode: .sourceAccurate) else {
                return false
            }
            if previous.tokenKind == .leftParen {
                return true
            }
            if previous.trailingTrivia.containsNewline {
                return false
            }
            token = previous
        }
        return false
    }
}
