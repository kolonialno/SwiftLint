import SwiftBasicFormat
import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(explicitRewriter: true, optIn: true)
struct MultilineCallArgumentsRule: Rule {
    var configuration = MultilineCallArgumentsConfiguration()

    enum Reason {
        static let singleLineMultipleArgumentsNotAllowed =
            "Single-line calls with multiple arguments are not allowed"

        static func tooManyArgumentsOnSingleLine(max: Int) -> String {
            "Too many arguments on a single line (max: \(max))"
        }

        static let eachArgumentMustStartOnOwnLine =
            "In multi-line calls, each argument must start on its own line"

        static let newlineRequiredAfterCommaInMultilineCall =
            "In multi-line calls, a newline is required after each comma"

        static let singleLineRequiredWithinAllowance =
            "Arguments within the single-line allowance must be on one line"
    }

    static let description = RuleDescription(
        identifier: "multiline_call_arguments",
        name: "Multiline Call Arguments",
        description: """
        Enforces one-argument-per-line for multi-line calls and requires a newline after commas \
        when arguments are split across lines;
        optionally limits or forbids multi-argument single-line calls via configuration.
        """,
        kind: .style,
        nonTriggeringExamples: MultilineCallArgumentsRuleExamples.nonTriggeringExamples,
        triggeringExamples: MultilineCallArgumentsRuleExamples.triggeringExamples,
        corrections: MultilineCallArgumentsRuleExamples.corrections
    )
}

private extension MultilineCallArgumentsRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        /// Cache line lookups by utf8Offset (stable, cheap key)
        private var lineCache: [Int: Int] = [:]

        override init(configuration: ConfigurationType, file: SwiftLintFile) {
            super.init(configuration: configuration, file: file)

            // Most files trigger O(10–100) unique line lookups for this rule.
            // Reserving a small initial capacity reduces rehashing; it is NOT a hard limit.
            lineCache.reserveCapacity(64)
        }

        override func visitPost(_ node: FunctionCallExprSyntax) {
            // Ignore calls that are part of pattern-matching syntax (patterns only, not bodies).
            guard !node.isInPatternMatchingPatternPosition else { return }

            if let violation = splitWithinAllowanceViolation(in: node) {
                violations.append(violation)
                return
            }

            let args = node.arguments
            guard args.count > 1 else { return }

            let argumentPositions = args.map(\.positionAfterSkippingLeadingTrivia)
            guard let violation = reasonedViolation(argumentPositions: argumentPositions, arguments: args) else {
                return
            }
            violations.append(violation)
        }

        private func reasonedViolation(
            argumentPositions: [AbsolutePosition],
            arguments: LabeledExprListSyntax
        ) -> ReasonedRuleViolation? {
            guard let firstPos = argumentPositions.first else { return nil }

            let firstLine = line(for: firstPos)
            var allOnSameLine = true
            for pos in argumentPositions.dropFirst() where line(for: pos) != firstLine {
                allOnSameLine = false
                break
            }

            if allOnSameLine {
                if !configuration.allowsSingleLine {
                    return ReasonedRuleViolation(
                        position: argumentPositions[1],
                        reason: Reason.singleLineMultipleArgumentsNotAllowed
                    )
                }

                if let max = configuration.maxNumberOfSingleLineParameters,
                   argumentPositions.count > max {
                    return ReasonedRuleViolation(
                        position: argumentPositions[max],
                        reason: Reason.tooManyArgumentsOnSingleLine(max: max)
                    )
                }

                return nil
            }

            if let startLineViolation = duplicateArgumentStartLineViolation(in: arguments) {
                return startLineViolation
            }

            if let commaViolation = newlineAfterCommaViolation(in: arguments) {
                return commaViolation
            }

            return nil
        }

        private func duplicateArgumentStartLineViolation(
            in arguments: LabeledExprListSyntax
        ) -> ReasonedRuleViolation? {
            let args = Array(arguments)
            guard args.count > 1 else { return nil }

            var seen: Set<Int> = []
            for arg in args {
                let startPos = startPosition(of: arg)
                let line = line(for: startPos)
                if !seen.insert(line).inserted {
                    return ReasonedRuleViolation(
                        position: startPos,
                        reason: Reason.eachArgumentMustStartOnOwnLine
                    )
                }
            }

            return nil
        }

        private func newlineAfterCommaViolation(in arguments: LabeledExprListSyntax) -> ReasonedRuleViolation? {
            let args = Array(arguments)
            guard args.count > 1 else { return nil }

            for index in args.indices.dropLast() {
                let current = args[index]
                let next = args[index + 1]

                guard let comma = current.trailingComma, comma.presence != .missing else { continue }

                if let lastToken = current.expression.lastToken(viewMode: .sourceAccurate) {
                    switch lastToken.tokenKind {
                    case .rightBrace,
                        .rightSquare:
                        continue
                    default:
                        break
                    }
                }

                let commaLine = line(for: comma.positionAfterSkippingLeadingTrivia)
                let currentStartLine = line(for: startPosition(of: current))
                let nextStartPos = startPosition(of: next)
                let nextStartLine = line(for: nextStartPos)

                if commaLine == nextStartLine, currentStartLine != nextStartLine {
                    return ReasonedRuleViolation(
                        position: nextStartPos,
                        reason: Reason.newlineRequiredAfterCommaInMultilineCall
                    )
                }
            }

            return nil
        }

        /// A list within the allowance that is split anyway, which the rewriter brings back to one line.
        private func splitWithinAllowanceViolation(in node: FunctionCallExprSyntax) -> ReasonedRuleViolation? {
            guard configuration.requiresSingleLine,
                  let first = node.arguments.first,
                  !node.argumentsAreOnOneLine,
                  !node.exceedsSingleLineAllowance(configuration),
                  node.argumentsCanRejoinOneLine(configuration)
            else {
                return nil
            }
            return ReasonedRuleViolation(
                position: startPosition(of: first),
                reason: Reason.singleLineRequiredWithinAllowance
            )
        }

        private func startPosition(of argument: LabeledExprSyntax) -> AbsolutePosition {
            if let label = argument.label, label.presence != .missing {
                return label.positionAfterSkippingLeadingTrivia
            }
            return argument.expression.positionAfterSkippingLeadingTrivia
        }

        private func line(for position: AbsolutePosition) -> Int {
            let key = position.utf8Offset
            if let cached = lineCache[key] { return cached }
            let line = locationConverter.location(for: position).line
            lineCache[key] = line
            return line
        }
    }
}

private extension MultilineCallArgumentsRule {
    /// Writes the shape out in full rather than inserting a single break, because a formatter running
    /// afterwards decides the rest of the layout for a whole expression at once — hand it half a shape and
    /// it resolves nested lists its own way, which is how a corrector and a formatter end up trading the
    /// same edit forever.
    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
            guard !node.isInPatternMatchingPatternPosition, node.rightParen != nil else {
                return super.visit(node)
            }
            let exceedsAllowance = node.exceedsSingleLineAllowance(configuration)
            if node.arguments.count > 1, exceedsAllowance, node.argumentsAreOnOneLine {
                numberOfCorrections += 1
                return super.visit(split(node))
            }
            if configuration.requiresSingleLine, !exceedsAllowance, !node.argumentsAreOnOneLine,
               !node.arguments.isEmpty, node.argumentsCanRejoinOneLine(configuration) {
                numberOfCorrections += 1
                return super.visit(joined(node))
            }
            return super.visit(node)
        }

        private func split(_ node: FunctionCallExprSyntax) -> FunctionCallExprSyntax {
            // Indentation read from the tree rather than from source columns, so a nested list still lands
            // right: recursion happens after the rewrite, so by the time an inner call is visited it sits on
            // the line this rewrite just gave it.
            let indentation = node.firstToken(viewMode: .sourceAccurate)?.indentationOfLine ?? []
            let arguments = LabeledExprListSyntax(
                node.arguments.map { argument in
                    argument
                        .with(\.leadingTrivia, .newline + indentation + .spaces(4))
                        .with(\.trailingComma, argument.trailingComma?.with(\.trailingTrivia, []))
                }
            )
            return node
                .with(\.arguments, arguments)
                .with(\.rightParen, node.rightParen?.with(\.leadingTrivia, .newline + indentation))
        }

        /// Deciding both directions is what makes the shape a function of the argument count rather than of
        /// the call's history: a call that loses an argument comes back to one line instead of keeping the
        /// shape it had when it was longer.
        private func joined(_ node: FunctionCallExprSyntax) -> FunctionCallExprSyntax {
            let last = node.arguments.count - 1
            let arguments = LabeledExprListSyntax(
                node.arguments.enumerated().map { index, argument in
                    // A trailing comma on the last argument reads as a shape marker only while the list is
                    // split; on one line it is noise, so the join drops it.
                    let comma = index == last
                        ? nil
                        : argument.trailingComma?.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
                    return argument
                        .with(\.leadingTrivia, index == 0 ? [] : .space)
                        .with(\.trailingTrivia, [])
                        .with(\.trailingComma, comma)
                }
            )
            return node
                .with(\.leftParen, node.leftParen?.with(\.trailingTrivia, []))
                .with(\.arguments, arguments)
                .with(\.rightParen, node.rightParen?.with(\.leadingTrivia, []))
        }
    }
}

private extension FunctionCallExprSyntax {
    /// Read from trivia rather than from source locations, because a rewrite moves everything after it and
    /// the location converter still answers from the file as it was read. A list nested in one that has
    /// already been reshaped is exactly the case that matters, and locations there are stale.
    var argumentsAreOnOneLine: Bool {
        arguments.tokens(viewMode: .sourceAccurate).allSatisfy { token in
            !token.leadingTrivia.containsNewline
                && !token.trailingTrivia.containsNewline
                && !token.text.contains("\n")
        }
    }

    func exceedsSingleLineAllowance(_ configuration: MultilineCallArgumentsConfiguration) -> Bool {
        if !configuration.allowsSingleLine {
            return true
        }
        guard let maximum = configuration.maxNumberOfSingleLineParameters else {
            return false
        }
        return arguments.count > maximum
    }

    /// Whether the breaks in this list hold nothing a join would destroy — no comment to lose, no closure
    /// body, no multiline string — since a join only takes back the breaks this rule would have made.
    func argumentsCanRejoinOneLine(_ configuration: MultilineCallArgumentsConfiguration) -> Bool {
        guard rightParen?.leadingTrivia.containsComment != true else {
            return false
        }
        return arguments.allSatisfy { argument in
            !argument.trimmedDescription.contains("\n")
                && !argument.leadingTrivia.containsComment
                && !argument.trailingTrivia.containsComment
                && !argument.containsCallNeedingItsOwnShape(configuration)
        }
    }
}

private extension SyntaxProtocol {
    /// A join yields to anything inside it that this rule will split, since a list on one line whose
    /// argument spans several reads worse than the split list it came from.
    func containsCallNeedingItsOwnShape(_ configuration: MultilineCallArgumentsConfiguration) -> Bool {
        children(viewMode: .sourceAccurate).contains { child in
            if let call = child.as(FunctionCallExprSyntax.self),
               call.arguments.count > 1,
               call.exceedsSingleLineAllowance(configuration),
               call.argumentsAreOnOneLine {
                return true
            }
            return child.containsCallNeedingItsOwnShape(configuration)
        }
    }
}

private extension FunctionCallExprSyntax {
    /// Returns `true` if this call appears in a pattern position (e.g., `case .foo(a)`).
    ///
    /// Works because SwiftSyntax wraps pattern expressions in `ExpressionPatternSyntax`:
    /// - `if case let .foo(a) = x` → parent is ExpressionPatternSyntax
    /// - `switch x { case let .foo(a): }` → parent is ExpressionPatternSyntax
    /// - `for case let .foo(a) in items` → parent is ExpressionPatternSyntax
    /// - `catch .foo(1, 2)` → parent is ExpressionPatternSyntax
    var isInPatternMatchingPatternPosition: Bool {
        parent?.is(ExpressionPatternSyntax.self) == true
    }
}

private extension Trivia {
    var containsNewline: Bool {
        contains(where: \.isNewline)
    }

    var containsComment: Bool {
        contains(where: \.isComment)
    }
}
