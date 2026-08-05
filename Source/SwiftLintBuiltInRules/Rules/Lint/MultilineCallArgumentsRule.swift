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
            guard !arguments.holdsOnlyNumbers else {
                // A list of bare numbers is horizontal at any length, so neither direction has anything to say.
                return nil
            }

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
                  !node.arguments.isOnOneLine,
                  !node.arguments.exceedsSingleLineAllowance(configuration),
                  node.argumentsCanRejoinOneLine
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
    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
            guard !node.isInPatternMatchingPatternPosition, node.rightParen != nil else {
                return super.visit(node)
            }
            if node.arguments.count > 1,
               node.arguments.exceedsSingleLineAllowance(configuration),
               node.arguments.isOnOneLine,
               !node.arguments.containsComment {
                numberOfCorrections += 1
                let indentation = node.indentationOfOwnLine
                return super.visit(
                    node
                        .with(\.arguments, node.arguments.splitOnePerLine(from: indentation))
                        .with(\.rightParen, node.rightParen?.with(\.leadingTrivia, .newline + indentation))
                )
            }
            // A split is decided before descending, so that a nested list can read the line this put it on.
            // A join is decided after: an inner list coming back to one line is what makes the outer one
            // joinable, and deciding first would leave that for a second run over the file.
            let visited = super.visit(node)
            guard configuration.requiresSingleLine,
                  let call = visited.as(FunctionCallExprSyntax.self),
                  !call.arguments.exceedsSingleLineAllowance(configuration),
                  !call.arguments.isOnOneLine,
                  call.argumentsCanRejoinOneLine
            else {
                return visited
            }
            numberOfCorrections += 1
            return ExprSyntax(
                call
                    .with(\.leftParen, call.leftParen?.with(\.trailingTrivia, []))
                    .with(\.arguments, call.arguments.joinedOnOneLine(startingWith: []))
                    .with(\.rightParen, call.rightParen?.with(\.leadingTrivia, []))
            )
        }
    }
}

extension MultilineCallArgumentsConfiguration: SingleLineAllowance {}

private extension FunctionCallExprSyntax {
    var argumentsCanRejoinOneLine: Bool {
        !arguments.isEmpty
            && rightParen?.leadingTrivia.containsComment != true
            && arguments.canRejoinOneLine
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
