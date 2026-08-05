import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct TiendaAPIKitIsUIFreeRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "tienda_api_kit_is_ui_free",
        name: "Tienda API Kit Is UI Free",
        description: "TiendaAPIKit has no UI — it must not import UI frameworks",
        kind: .lint,
        nonTriggeringExamples: #examples([
            "import Foundation",
            "import OSLog",
            "class ViewModel {}",
        ]),
        triggeringExamples: #examples([
            "↓import UIKit",
            "↓import SwiftUI",
            "↓import AppKit",
            "↓import WatchKit",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension TiendaAPIKitIsUIFreeRule {
    static let frameworks: Set<String> = ["UIKit", "SwiftUI", "AppKit", "WatchKit"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: ImportDeclSyntax) {
            guard let module = node.path.first?.name.text,
                TiendaAPIKitIsUIFreeRule.frameworks.contains(module)
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
