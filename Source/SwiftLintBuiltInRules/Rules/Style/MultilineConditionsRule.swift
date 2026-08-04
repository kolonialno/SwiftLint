import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(explicitRewriter: true, optIn: true)
struct MultilineConditionsRule: Rule {
    var configuration = MultilineConditionsConfiguration()

    enum Reason {
        static func tooManyConditionsOnSingleLine(max: Int) -> String {
            "Too many conditions on a single line (max: \(max))"
        }

        static let singleLineConditionsNotAllowed =
            "Single-line multiple conditions are not allowed"

        static let eachConditionMustStartOnOwnLine =
            "In multi-line conditions, each condition after the first must start on its own line"

        static let singleLineRequiredWithinAllowance =
            "Conditions within the single-line allowance must be on one line"
    }

    static let description = RuleDescription(
        identifier: "multiline_conditions",
        name: "Multiline Conditions",
        description: """
        Conditions of an `if`, `guard` or `while` should be either on the same line, or one per line \
        after the first; optionally limits or forbids multi-condition single lines via configuration.
        """,
        kind: .style,
        nonTriggeringExamples: MultilineConditionsRuleExamples.nonTriggeringExamples,
        triggeringExamples: MultilineConditionsRuleExamples.triggeringExamples,
        corrections: MultilineConditionsRuleExamples.corrections
    )
}

private extension MultilineConditionsRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: IfExprSyntax) {
            report(node.conditions)
        }

        override func visitPost(_ node: GuardStmtSyntax) {
            report(node.conditions)
        }

        override func visitPost(_ node: WhileStmtSyntax) {
            report(node.conditions)
        }

        private func report(_ conditions: ConditionElementListSyntax) {
            guard let first = conditions.first, let reason = reason(for: conditions) else {
                return
            }
            violations.append(
                ReasonedRuleViolation(
                    position: first.positionAfterSkippingLeadingTrivia,
                    reason: reason
                )
            )
        }

        private func reason(for conditions: ConditionElementListSyntax) -> String? {
            if conditions.isOnOneLine {
                guard conditions.count > 1 else {
                    return nil
                }
                if !configuration.allowsSingleLine {
                    return Reason.singleLineConditionsNotAllowed
                }
                if let maximum = configuration.maxNumberOfSingleLineParameters,
                   conditions.count > maximum {
                    return Reason.tooManyConditionsOnSingleLine(max: maximum)
                }
                return nil
            }
            if configuration.requiresSingleLine,
               !conditions.exceedsSingleLineAllowance(configuration),
               conditions.canRejoinOneLine {
                return Reason.singleLineRequiredWithinAllowance
            }
            // One condition has nothing to align against, and a lone condition that spans lines reads
            // better below the keyword than beside it — so the shape only applies from two.
            guard conditions.count > 1, !conditions.isSplitAfterTheFirst else {
                return nil
            }
            return Reason.eachConditionMustStartOnOwnLine
        }
    }

    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: IfExprSyntax) -> ExprSyntax {
            if let split = splitting(node.conditions, of: node) {
                return super.visit(reshaped(node, with: split))
            }
            let visited = super.visit(node)
            guard let expression = visited.as(IfExprSyntax.self),
                  let joined = joining(expression.conditions)
            else {
                return visited
            }
            return ExprSyntax(reshaped(expression, with: joined))
        }

        override func visit(_ node: GuardStmtSyntax) -> StmtSyntax {
            if let split = splitting(node.conditions, of: node) {
                return super.visit(reshaped(node, with: split))
            }
            let visited = super.visit(node)
            guard let statement = visited.as(GuardStmtSyntax.self),
                  let joined = joining(statement.conditions)
            else {
                return visited
            }
            return StmtSyntax(reshaped(statement, with: joined))
        }

        override func visit(_ node: WhileStmtSyntax) -> StmtSyntax {
            if let split = splitting(node.conditions, of: node) {
                return super.visit(reshaped(node, with: split))
            }
            let visited = super.visit(node)
            guard let statement = visited.as(WhileStmtSyntax.self),
                  let joined = joining(statement.conditions)
            else {
                return visited
            }
            return StmtSyntax(reshaped(statement, with: joined))
        }

        /// Decided before descending, so that a nested list can read the line this puts it on.
        private func splitting(
            _ conditions: ConditionElementListSyntax,
            of node: some SyntaxProtocol
        ) -> ConditionElementListSyntax? {
            guard conditions.count > 1,
                  conditions.exceedsSingleLineAllowance(configuration),
                  !conditions.isSplitAfterTheFirst,
                  !conditions.containsComment
            else {
                return nil
            }
            numberOfCorrections += 1
            return conditions.splitAfterTheFirst(from: node.indentationOfOwnLine)
        }

        /// Decided after descending: a call inside a condition coming back to one line is what can make the
        /// whole list joinable, and deciding first would leave that for a second run over the file.
        private func joining(_ conditions: ConditionElementListSyntax) -> ConditionElementListSyntax? {
            guard configuration.requiresSingleLine,
                  !conditions.isEmpty,
                  !conditions.exceedsSingleLineAllowance(configuration),
                  !conditions.isOnOneLine,
                  conditions.canRejoinOneLine
            else {
                return nil
            }
            numberOfCorrections += 1
            return conditions.joinedOnOneLine(startingWith: [])
        }

        private func reshaped(_ node: IfExprSyntax, with conditions: ConditionElementListSyntax) -> IfExprSyntax {
            node
                .with(\.ifKeyword, node.ifKeyword.with(\.trailingTrivia, .space))
                .with(\.conditions, conditions)
                .with(\.body, node.body.openingBracePlaced(after: conditions, of: node))
        }

        private func reshaped(
            _ node: GuardStmtSyntax,
            with conditions: ConditionElementListSyntax
        ) -> GuardStmtSyntax {
            node
                .with(\.guardKeyword, node.guardKeyword.with(\.trailingTrivia, .space))
                .with(\.conditions, conditions)
                .with(
                    \.elseKeyword,
                    node.elseKeyword.with(
                        \.leadingTrivia,
                        conditions.isOnOneLine ? .space : .newline + node.indentationOfOwnLine
                    )
                )
        }

        private func reshaped(
            _ node: WhileStmtSyntax,
            with conditions: ConditionElementListSyntax
        ) -> WhileStmtSyntax {
            node
                .with(\.whileKeyword, node.whileKeyword.with(\.trailingTrivia, .space))
                .with(\.conditions, conditions)
                .with(\.body, node.body.openingBracePlaced(after: conditions, of: node))
        }
    }
}

extension MultilineConditionsConfiguration: SingleLineAllowance {}

private extension CodeBlockSyntax {
    /// The block with its opening brace where the conditions leave room for it: below them once they are
    /// split, since a brace trailing the last condition reads as part of that condition.
    func openingBracePlaced(
        after conditions: ConditionElementListSyntax,
        of node: some SyntaxProtocol
    ) -> Self {
        with(
            \.leftBrace,
            leftBrace.with(
                \.leadingTrivia,
                conditions.isOnOneLine ? .space : .newline + node.indentationOfOwnLine
            )
        )
    }
}
