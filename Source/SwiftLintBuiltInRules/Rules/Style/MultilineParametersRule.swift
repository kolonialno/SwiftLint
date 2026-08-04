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
            configuration.requiresSingleLine && signature.parameterClause.canRejoinOneLine(configuration)
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
            super.visit(node.with(\.signature, reshaped(node.signature)))
        }

        override func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
            super.visit(node.with(\.signature, reshaped(node.signature)))
        }

        /// The signature with its parameters in the shape their count asks for, or unchanged when they
        /// already have it.
        private func reshaped(_ signature: FunctionSignatureSyntax) -> FunctionSignatureSyntax {
            let clause = signature.parameterClause
            let parameters = clause.parameters
            guard !parameters.isEmpty else {
                return signature
            }
            let exceedsAllowance = parameters.exceedsSingleLineAllowance(configuration)
            if parameters.count > 1, exceedsAllowance, parameters.isOnOneLine {
                numberOfCorrections += 1
                return signature.with(\.parameterClause, split(clause))
            }
            if configuration.requiresSingleLine, !exceedsAllowance, clause.canRejoinOneLine(configuration) {
                numberOfCorrections += 1
                return signature.with(
                    \.parameterClause,
                    clause
                        .with(\.leftParen, clause.leftParen.with(\.trailingTrivia, []))
                        .with(\.parameters, parameters.joinedOnOneLine())
                        .with(\.rightParen, clause.rightParen.with(\.leadingTrivia, []))
                )
            }
            // Neither one line nor one per line, which is the shape this rule is named for.
            if parameters.isSplitUnevenly {
                numberOfCorrections += 1
                return signature.with(\.parameterClause, split(clause))
            }
            return signature
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
    func canRejoinOneLine(_ configuration: MultilineParametersConfiguration) -> Bool {
        !parameters.isEmpty
            && !parameters.isOnOneLine
            && !parameters.exceedsSingleLineAllowance(configuration)
            && !rightParen.leadingTrivia.containsComment
            && parameters.canRejoinOneLine(configuration)
    }
}
