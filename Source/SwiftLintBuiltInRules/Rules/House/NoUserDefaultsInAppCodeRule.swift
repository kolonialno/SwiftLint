import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoUserDefaultsInAppCodeRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_user_defaults_in_app_code",
        name: "No User Defaults In App Code",
        description: """
            Persist through an injected value storage. @AppStorage is allowed only with a key from the one \
            type that owns the remaining defaults keys
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "@AppStorage(AppStorageKey.adVariant) private var variant = \"\"",
            "let storage: any ValueStoring",
            "struct Defaults { let name: String }",
        ]),
        triggeringExamples: #examples([
            "let defaults = ↓UserDefaults.standard",
            "↓UserDefaults(suiteName: \"group.oda\")?.set(true, forKey: \"seen\")",
            "func read(from defaults: ↓UserDefaults) {}",
            "↓@AppStorage(\"seenOnboarding\") private var seen = false",
            "↓@AppStorage(OtherKeys.seen) private var seen = false",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoUserDefaultsInAppCodeRule {
    /// The one type allowed to name an `@AppStorage` key, so the remaining defaults keys live in one place.
    static let keyOwner = "AppStorageKey"

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: TokenSyntax) {
            guard case .identifier("UserDefaults") = node.tokenKind else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }

        override func visitPost(_ node: AttributeSyntax) {
            guard node.attributeName.trimmedDescription == "AppStorage",
                case let .argumentList(arguments) = node.arguments
            else {
                return
            }
            let key = arguments.first?.expression.as(MemberAccessExprSyntax.self)
            guard key?.base?.trimmedDescription != NoUserDefaultsInAppCodeRule.keyOwner else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
