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
            return node.with(
                \.leadingTrivia,
                node.leadingTrivia.reindented(to: wanted, commentsAt: node.commentIndentation(wanted: wanted)))
        }
    }
}

private extension TriviaPiece {
    var isComment: Bool {
        switch self {
        case .lineComment, .blockComment, .docLineComment, .docBlockComment: true
        default: false
        }
    }
}

extension TokenSyntax {
    /// Where a comment on its own line in front of this token belongs.
    ///
    /// Usually with the token it introduces, but a comment in front of a closing brace is the last thing
    /// inside the block, so it keeps the block's level rather than stepping back out with the brace.
    func commentIndentation(wanted: Int, width: Int = 4) -> Int {
        switch tokenKind {
        case .rightBrace, .rightParen, .rightSquare: wanted + width
        default: wanted
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
            if parent.isStatementContinued(by: node) {
                // `let x =` or `return` with the value on the next line: the value continues the statement.
                steps += 1
            }
            if parent.kind == .exprList,
                let broken = parent.firstBrokenElement,
                position >= broken.position,
                parent.opensAnElement(at: self) {
                // Operators and ternaries reach a rule unfolded, as a flat sequence, so the continuation
                // is counted once for the whole sequence: `a\n && b\n && c` steps in once, and so does
                // `condition\n ? this\n : that`.
                steps += 1
            }
            if parent.isMemberChainRoot,
                let broken = parent.firstBrokenPeriod,
                position >= broken.position,
                !parent.chainBaseIsMultiline,
                !parent.continuesAStatement {
                // A wrapped chain is one continuation level, counted once at its root and only from the
                // break onwards, so its base still sits on the line that opened it. A chain hanging off a
                // *multiline* base keeps that base's own level instead: `VStack { … }` then `.padding()`
                // aligns with the `VStack`, while `Rectangle(…)` then `.fill()` steps in.
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
    /// Whether this list puts any of its elements on a line of its own, which is what opens a level.
    ///
    /// A list that stays on one line opens nothing, however deeply the expressions inside it wrap: the
    /// arguments of `if Self.isInCart(\n  id: id\n)` step in once, from the call, not twice.
    var isBroken: Bool {
        children(viewMode: .sourceAccurate).contains { $0.leadingTrivia.containsNewline }
    }

    /// Whether `token` is where one of this list's own elements begins.
    ///
    /// A continuation belongs to the sequence's own lines. Anything nested inside an element — a closure
    /// body, a wrapped argument list — has its own levels and must not collect this one as well.
    func opensAnElement(at token: TokenSyntax) -> Bool {
        children(viewMode: .sourceAccurate)
            .contains { $0.firstToken(viewMode: .sourceAccurate)?.id == token.id }
    }

    /// The first element of this sequence to open a line, which is where its continuation begins.
    ///
    /// The first element never counts: it is where the sequence starts, and whatever put it on its own line
    /// — a `return`, an `=` — has already indented it.
    var firstBrokenElement: Syntax? {
        children(viewMode: .sourceAccurate).dropFirst().first { $0.leadingTrivia.containsNewline }
    }

    /// Whether `value` is this statement's own value and starts a line of its own — the `return` keyword
    /// and the `=` are part of the statement, so only what follows them continues it.
    func isStatementContinued(by value: Syntax) -> Bool {
        guard value.leadingTrivia.containsNewline else {
            return false
        }
        if let returned = self.as(ReturnStmtSyntax.self)?.expression {
            return Syntax(returned).id == value.id
        }
        if let initialized = self.as(InitializerClauseSyntax.self)?.value {
            return Syntax(initialized).id == value.id
        }
        return false
    }

    /// Whether this expression is the value of a `return` or an `=` that put it on its own line, in which
    /// case it is already one level in and a chain hanging off it maintains that level.
    var continuesAStatement: Bool {
        guard let parent else {
            return false
        }
        return parent.isStatementContinued(by: self)
    }

    /// Whether this is the outermost expression of an operator chain, where its one level is counted.
    var isOperatorChainRoot: Bool {
        kind == .infixOperatorExpr && parent?.kind != .infixOperatorExpr
    }

    /// The first operator of this chain to open a line. Operands nest to the left, so the outermost
    /// expression carries the *last* operator — the chain has to be walked to find where it first broke.
    var firstBrokenOperator: TokenSyntax? {
        var operators: [TokenSyntax] = []
        var link: Syntax? = self
        while let node = link, let expression = node.as(InfixOperatorExprSyntax.self) {
            if let token = expression.operator.firstToken(viewMode: .sourceAccurate) {
                operators.append(token)
            }
            link = Syntax(expression.leftOperand)
        }
        return operators
            .filter { $0.leadingTrivia.containsNewline }
            .min { $0.position < $1.position }
    }

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

    /// Whether what the chain hangs off spans lines of its own.
    var chainBaseIsMultiline: Bool {
        var link: Syntax? = self
        var base: Syntax?
        while let node = link {
            if let member = node.as(MemberAccessExprSyntax.self) {
                base = member.base.map(Syntax.init)
                link = base
            } else if node.isMemberChainLink, let call = node.as(FunctionCallExprSyntax.self) {
                link = Syntax(call.calledExpression)
            } else {
                break
            }
        }
        return base?.trimmedDescription.contains("\n") == true
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
            } else if node.isMemberChainLink, let call = node.as(FunctionCallExprSyntax.self) {
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
            // A file's own statements are already at the outermost level, and the house formatter does not
            // indent what `#if` wraps.
            if parent?.is(SourceFileSyntax.self) == true || parent?.is(IfConfigClauseSyntax.self) == true {
                return false
            }
            return isBroken
        case .memberBlockItemList, .accessorDeclList,
            .labeledExprList, .functionParameterList, .closureParameterList,
            .arrayElementList, .dictionaryElementList, .conditionElementList,
            .enumCaseParameterList, .switchCaseItemList, .genericParameterList,
            .inheritedTypeList, .tupleTypeElementList, .tupleExprElementList:
            return isBroken
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
    func reindented(to spaces: Int, commentsAt commentSpaces: Int) -> Trivia {
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
                    pieces.append(.spaces(piece.isComment ? commentSpaces : spaces))
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
