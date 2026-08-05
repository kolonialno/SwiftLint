import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(explicitRewriter: true, optIn: true)
struct MultilineParametersRule: Rule {
    var configuration = MultilineParametersConfiguration()

    static let description = RuleDescription(
        identifier: "multiline_parameters",
        name: "Multiline Parameters",
        description: "Functions and methods parameters should be either on the same line, or one per line",
        kind: .style,
        nonTriggeringExamples: MultilineParametersRuleExamples.nonTriggeringExamples,
        triggeringExamples: MultilineParametersRuleExamples.triggeringExamples,
        corrections: MultilineParametersRuleExamples.corrections
    )
}

private extension MultilineParametersRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionDeclSyntax) {
            if containsViolation(for: node.signature) || isSplitWithinAllowance(node.signature) {
                violations.append(node.name.positionAfterSkippingLeadingTrivia)
            }
        }

        override func visitPost(_ node: InitializerDeclSyntax) {
            if containsViolation(for: node.signature) || isSplitWithinAllowance(node.signature) {
                violations.append(node.initKeyword.positionAfterSkippingLeadingTrivia)
            }
        }

        /// A parameter list within the allowance that is split anyway, which the rewriter brings back to
        /// one line.
        private func isSplitWithinAllowance(_ signature: FunctionSignatureSyntax) -> Bool {
            configuration.requiresSingleLine
                && signature.parameterClause.canRejoinOneLine(within: configuration)
        }

        private func containsViolation(for signature: FunctionSignatureSyntax) -> Bool {
            let parameterPositions = signature.parameterClause.parameters.map(\.positionAfterSkippingLeadingTrivia)
            guard parameterPositions.isNotEmpty else {
                return false
            }

            var numberOfParameters = 0
            var linesWithParameters: Set<Int> = []
            var hasMultipleParametersOnSameLine = false

            for position in parameterPositions {
                let line = locationConverter.location(for: position).line

                if !linesWithParameters.insert(line).inserted {
                    hasMultipleParametersOnSameLine = true
                }

                numberOfParameters += 1
            }

            if linesWithParameters.count == 1 {
                guard configuration.allowsSingleLine else {
                    return numberOfParameters > 1
                }

                if let maxNumberOfSingleLineParameters = configuration.maxNumberOfSingleLineParameters {
                    return numberOfParameters > maxNumberOfSingleLineParameters
                }

                return false
            }

            return hasMultipleParametersOnSameLine
        }
    }
}

private extension MultilineParametersRule {
    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
            if let split = splitting(node.signature) {
                return super.visit(node.with(\.signature, split))
            }
            let visited = super.visit(node)
            guard let declaration = visited.as(FunctionDeclSyntax.self),
                  let joined = joining(declaration.signature)
            else {
                return visited
            }
            return DeclSyntax(declaration.with(\.signature, joined))
        }

        override func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
            if let split = splitting(node.signature) {
                return super.visit(node.with(\.signature, split))
            }
            let visited = super.visit(node)
            guard let declaration = visited.as(InitializerDeclSyntax.self),
                  let joined = joining(declaration.signature)
            else {
                return visited
            }
            return DeclSyntax(declaration.with(\.signature, joined))
        }

        /// The signature with its parameters one per line, or `nil` when they do not need it.
        ///
        /// Decided before descending, so that a nested list can read the line this puts it on.
        private func splitting(_ signature: FunctionSignatureSyntax) -> FunctionSignatureSyntax? {
            let clause = signature.parameterClause
            let parameters = clause.parameters
            guard !parameters.isEmpty, !parameters.containsComment else {
                return nil
            }
            let needsSplitting =
                (parameters.count > 1
                    && parameters.exceedsSingleLineAllowance(configuration)
                    && parameters.isOnOneLine)
                // Neither one line nor one per line, which is the shape this rule is named for. A list that
                // could simply come back to one line does that instead, since splitting it further would be
                // the opposite of what the allowance asks for — and the visitor reports the join, not a split.
                || (parameters.isSplitUnevenly && !clause.canRejoinOneLine(within: configuration))
            guard needsSplitting else {
                return nil
            }
            numberOfCorrections += 1
            return signature.with(\.parameterClause, split(clause))
        }

        /// The signature with its parameters back on one line, or `nil` when they cannot come back.
        ///
        /// Decided after descending: a default value coming back to one line is what can make the whole
        /// list joinable, and deciding first would leave that for a second run over the file.
        private func joining(_ signature: FunctionSignatureSyntax) -> FunctionSignatureSyntax? {
            let clause = signature.parameterClause
            guard configuration.requiresSingleLine, clause.canRejoinOneLine(within: configuration) else {
                return nil
            }
            numberOfCorrections += 1
            return signature.with(
                \.parameterClause,
                clause
                    .with(\.leftParen, clause.leftParen.with(\.trailingTrivia, []))
                    .with(\.parameters, clause.parameters.joinedOnOneLine(startingWith: []))
                    .with(\.rightParen, clause.rightParen.with(\.leadingTrivia, []))
            )
        }

        private func split(_ clause: FunctionParameterClauseSyntax) -> FunctionParameterClauseSyntax {
            let indentation = clause.indentationOfOwnLine
            return clause
                .with(\.parameters, clause.parameters.splitOnePerLine(from: indentation))
                .with(\.rightParen, clause.rightParen.with(\.leadingTrivia, .newline + indentation))
        }
    }
}

extension MultilineParametersConfiguration: SingleLineAllowance {}

private extension FunctionParameterClauseSyntax {
    /// Whether the parameters can come back to one line. The closing paren is checked here because a comment
    /// before it would be lost.
    func canRejoinOneLine(within allowance: some SingleLineAllowance) -> Bool {
        !parameters.isEmpty
            && !parameters.isOnOneLine
            && !parameters.exceedsSingleLineAllowance(allowance)
            && !rightParen.leadingTrivia.containsComment
            && parameters.canRejoinOneLine
    }
}
