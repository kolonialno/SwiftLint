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
               conditions.canRejoinOneLine(configuration) {
                return Reason.singleLineRequiredWithinAllowance
            }
            return conditions.isSplitAfterTheFirst ? nil : Reason.eachConditionMustStartOnOwnLine
        }
    }

    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: IfExprSyntax) -> ExprSyntax {
            guard let conditions = reshaped(node.conditions, of: node) else {
                return super.visit(node)
            }
            return super.visit(
                node
                    .with(\.ifKeyword, node.ifKeyword.with(\.trailingTrivia, .space))
                    .with(\.conditions, conditions)
                    .with(\.body, node.body.openingBracePlaced(after: conditions, of: node))
            )
        }

        override func visit(_ node: GuardStmtSyntax) -> StmtSyntax {
            guard let conditions = reshaped(node.conditions, of: node) else {
                return super.visit(node)
            }
            return super.visit(
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
            )
        }

        override func visit(_ node: WhileStmtSyntax) -> StmtSyntax {
            guard let conditions = reshaped(node.conditions, of: node) else {
                return super.visit(node)
            }
            return super.visit(
                node
                    .with(\.whileKeyword, node.whileKeyword.with(\.trailingTrivia, .space))
                    .with(\.conditions, conditions)
                    .with(\.body, node.body.openingBracePlaced(after: conditions, of: node))
            )
        }

        /// The conditions in the shape their count asks for, or `nil` when they already have it.
        private func reshaped(
            _ conditions: ConditionElementListSyntax,
            of node: some SyntaxProtocol
        ) -> ConditionElementListSyntax? {
            guard !conditions.isEmpty else {
                return nil
            }
            let exceedsAllowance = conditions.exceedsSingleLineAllowance(configuration)
            if exceedsAllowance,
               conditions.count > 1,
               !conditions.isSplitAfterTheFirst,
               !conditions.containsComment {
                numberOfCorrections += 1
                return conditions.splitAfterTheFirst(from: node.indentationOfOwnLine)
            }
            if configuration.requiresSingleLine,
               !exceedsAllowance,
               !conditions.isOnOneLine,
               conditions.canRejoinOneLine(configuration) {
                numberOfCorrections += 1
                return conditions.joinedOnOneLine(startingWith: [])
            }
            return nil
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
