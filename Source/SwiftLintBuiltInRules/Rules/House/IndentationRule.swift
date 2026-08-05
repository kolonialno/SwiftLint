import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(explicitRewriter: true, optIn: true)
struct IndentationRule: Rule {
    var configuration = IndentationConfiguration()

    static let description = RuleDescription(
        identifier: "indentation",
        name: "Indentation",
        description: "A line is indented once for every construct that encloses it",
        kind: .style,
        nonTriggeringExamples: #examples([
            """
            struct Cart {
                let items: [Item]
            }
            """,
            """
            func pay() {
                if isReady {
                    charge()
                }
            }
            """,
            """
            let names = [
                "a",
                "b",
            ]
            """,
            """
            guard let name,
                !name.isEmpty
            else {
                return
            }
            """,
        ]),
        triggeringExamples: #examples([
            """
            struct Cart {
            ↓let items: [Item]
            }
            """,
            """
            func pay() {
                if isReady {
              ↓charge()
                }
            }
            """,
            """
            let names = [
                    ↓"a",
            ]
            """,
        ])
    )
}

private extension IndentationRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: TokenSyntax) {
            guard let current = node.indentationAsWritten,
                current != node.indentation(width: configuration.width)
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }

    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: TokenSyntax) -> TokenSyntax {
            guard let current = node.indentationAsWritten else {
                return node
            }
            let wanted = node.indentation(width: configuration.width)
            guard current != wanted else {
                return node
            }
            numberOfCorrections += 1
            return node.with(\.leadingTrivia, node.leadingTrivia.reindented(to: wanted))
        }
    }
}

extension TokenSyntax {
    /// The spaces this token's line actually starts with, or `nil` when the token does not open a line.
    var indentationAsWritten: Int? {
        guard !isInsideAMultilineStringLiteral else {
            return nil
        }
        var seenNewline = false
        var spaces = 0
        for piece in leadingTrivia.pieces {
            switch piece {
            case .newlines, .carriageReturnLineFeeds, .carriageReturns:
                seenNewline = true
                spaces = 0
            case let .spaces(count) where seenNewline:
                spaces += count
            case let .tabs(count) where seenNewline:
                spaces += count
            case .lineComment, .blockComment, .docLineComment, .docBlockComment:
                // A comment owns its own line's indentation, so stop at the first one.
                return seenNewline ? spaces : nil
            default:
                break
            }
        }
        return seenNewline ? spaces : nil
    }

    /// The indentation the enclosing constructs ask for: one step per construct that opens a new level.
    func indentation(width: Int) -> Int {
        var steps = 0
        var node = Syntax(self)
        while let parent = node.parent {
            if parent.opensAnIndentationLevel(for: node) {
                steps += 1
            }
            if parent.isMemberChainRoot, let broken = parent.firstBrokenPeriod,
                position >= broken.position {
                // A wrapped chain is one continuation level, counted once at its root and only for the
                // lines after the break — its base still sits on the line that opened it.
                steps += 1
            }
            node = parent
        }
        return steps * width
    }

    var isInsideAMultilineStringLiteral: Bool {
        var node: Syntax? = Syntax(self).parent
        while let current = node {
            if let literal = current.as(StringLiteralExprSyntax.self),
                literal.openingQuote.tokenKind == .multilineStringQuote {
                return true
            }
            node = current.parent
        }
        return false
    }
}

extension Syntax {
    /// Whether this is the outermost link of a member chain, which is where the chain's one level is counted.
    var isMemberChainRoot: Bool {
        guard isMemberChainLink else {
            return false
        }
        guard let parent else {
            return true
        }
        return !parent.isMemberChainLink
    }

    var isMemberChainLink: Bool {
        // `.init(…)` in a collection literal has no base, so it continues nothing — it is an element.
        if let member = self.as(MemberAccessExprSyntax.self) {
            return member.base != nil
        }
        if let call = self.as(FunctionCallExprSyntax.self),
            let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
            return member.base != nil
        }
        return false
    }

    /// The first `.` of this chain that opens a line, which is where its continuation begins.
    ///
    /// Only the chain's own links count. A period inside a trailing closure belongs to a chain of its own,
    /// and reading it as this chain's break indents the whole closure body one level too far.
    var firstBrokenPeriod: TokenSyntax? {
        var periods: [TokenSyntax] = []
        var link: Syntax? = self
        while let node = link {
            if let member = node.as(MemberAccessExprSyntax.self) {
                periods.append(member.period)
                link = member.base.map(Syntax.init)
            } else if let call = node.as(FunctionCallExprSyntax.self),
                call.calledExpression.is(MemberAccessExprSyntax.self) {
                link = Syntax(call.calledExpression)
            } else {
                link = nil
            }
        }
        return periods
            .filter { $0.leadingTrivia.containsNewline }
            .min { $0.position < $1.position }
    }
}

private extension Syntax {
    /// Whether this node puts its child on a deeper level than itself.
    ///
    /// Only the collections a construct wraps count, never the construct itself, so a closing brace or paren —
    /// whose parent is the construct rather than the collection — lands back on the outer level for free.
    func opensAnIndentationLevel(for child: Syntax) -> Bool {
        switch kind {
        case .codeBlockItemList:
            // A file's own statements are already at the outermost level.
            return parent?.is(SourceFileSyntax.self) == false
        case .memberBlockItemList, .accessorDeclList,
            .labeledExprList, .functionParameterList, .closureParameterList,
            .arrayElementList, .dictionaryElementList, .conditionElementList,
            .enumCaseParameterList, .switchCaseItemList, .genericParameterList,
            .inheritedTypeList:
            return true
        case .switchCaseList:
            // The house formatter keeps `case` at the `switch`'s level; only the bodies step in.
            return false
        default:
            return false
        }
    }
}

private extension Trivia {
    /// The same trivia with every line's leading whitespace replaced by `spaces`, comments included.
    func reindented(to spaces: Int) -> Trivia {
        var pieces: [TriviaPiece] = []
        var atLineStart = false
        for piece in self.pieces {
            switch piece {
            case .newlines, .carriageReturnLineFeeds, .carriageReturns:
                pieces.append(piece)
                atLineStart = true
            case .spaces, .tabs:
                if !atLineStart {
                    pieces.append(piece)
                }
            default:
                if atLineStart {
                    pieces.append(.spaces(spaces))
                    atLineStart = false
                }
                pieces.append(piece)
            }
        }
        if atLineStart {
            pieces.append(.spaces(spaces))
        }
        return Trivia(pieces: pieces)
    }
}
