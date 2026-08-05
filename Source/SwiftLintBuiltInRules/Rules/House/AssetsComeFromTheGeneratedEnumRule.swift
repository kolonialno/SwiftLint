import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct AssetsComeFromTheGeneratedEnumRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "assets_come_from_the_generated_enum",
        name: "Assets Come From The Generated Enum",
        description: """
            Name an asset through the generated Asset enum, which knows the bundle it lives in. Looking one \
            up by name searches the main bundle, so it silently finds nothing once the asset moves into a \
            package
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "Asset.Recipes.iconDifficultyEasy.swiftUIImage",
            "Image(systemName: \"heart\")",
            "Image(uiImage: photo)",
            "UIImage(named: \"delivery_truck\", in: .module, compatibleWith: nil)",
            "Image(\"delivery_truck\", bundle: .module)",
            "Text(\"a string, not an asset\")",
            "Color(theme.semanticColors.text.success)",
            "Image(name)",
        ]),
        triggeringExamples: #examples([
            "let icon = ↓#imageLiteral(resourceName: \"Recipes/IconDifficultyEasy\")",
            "let icon = ↓UIImage(named: \"Recipes/IconDifficultyEasy\")",
            "↓Image(\"delivery_truck\")",
            "↓Image(decorative: \"delivery_truck\")",
            "let colour = ↓UIColor(named: \"Brand/Accent\")",
            "↓Color(\"Brand/Accent\")",
            "↓UIImage(named: page.asset)",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension AssetsComeFromTheGeneratedEnumRule {
    /// The initializers that look an asset up by name, and the label that says so.
    ///
    /// `named:` names an asset whatever the argument is, so any expression there is a lookup. `Image(_:)` and
    /// `Color(_:)` are the ambiguous pair: the same position also takes a `UIImage` or `UIColor` to convert,
    /// and without type information only a string literal tells them apart.
    static let labelled: Set<String> = ["UIImage", "UIColor"]
    static let unlabelledNeedingALiteral: Set<String> = ["Image", "Color"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: MacroExpansionExprSyntax) {
            guard node.macroName.text == "imageLiteral" else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }

        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard let type = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
                let name = node.arguments.first,
                // An explicit bundle says which one, which is the whole point.
                !node.arguments.contains(where: { $0.label?.text == "in" || $0.label?.text == "bundle" })
            else {
                return
            }
            let label = name.label?.text
            let namesAnAsset =
                (AssetsComeFromTheGeneratedEnumRule.labelled.contains(type) && label == "named")
                || (AssetsComeFromTheGeneratedEnumRule.unlabelledNeedingALiteral.contains(type)
                    && (label == nil || label == "decorative")
                    && name.expression.is(StringLiteralExprSyntax.self))
            guard namesAnAsset else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
