import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoLiveUIKitFrameReadsRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "no_live_uikit_frame_reads",
        name: "No Live UIKit Frame Reads",
        description: """
            A computed property is body-reachable — measuring a live UIKit bar there wedges the view. Read it \
            from a side effect instead
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "var inset: CGFloat { window.safeAreaInsets.bottom }",
            "var size: CGSize { proxy.size }",
            """
            func measure() -> CGFloat {
                navigationController?.navigationBar.frame.height ?? 0
            }
            """,
            """
            var height: CGFloat = 0
            """,
            """
            .onAppear {
                height = tabBarController?.tabBar.frame.height ?? 0
            }
            """,
        ]),
        triggeringExamples: #examples([
            """
            ↓var height: CGFloat {
                navigationController?.navigationBar.frame.height ?? 0
            }
            """,
            """
            ↓var barFrame: CGRect {
                tabBarController!.tabBar.frame
            }
            """,
            """
            ↓var size: CGSize {
                let bar = navigationController?.navigationBar.frame.size
                return bar ?? .zero
            }
            """,
        ])
    )
}

private extension NoLiveUIKitFrameReadsRule {
    static let measurements: Set<String> = ["CGFloat", "CGRect", "CGSize"]
    static let liveBars: Set<String> = ["navigationBar", "tabBar"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: VariableDeclSyntax) {
            guard let binding = node.bindings.onlyElement,
                let type = binding.typeAnnotation?.type.trimmedDescription,
                NoLiveUIKitFrameReadsRule.measurements.contains(type),
                let body = binding.accessorBlock,
                LiveBarFrameReader(viewMode: .sourceAccurate).readsALiveBar(in: body)
            else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }

    /// Finds `…navigationBar.frame` / `…tabBar.frame` anywhere inside a getter, at any nesting.
    final class LiveBarFrameReader: SyntaxVisitor {
        private var found = false

        func readsALiveBar(in body: AccessorBlockSyntax) -> Bool {
            found = false
            walk(body)
            return found
        }

        override func visitPost(_ node: MemberAccessExprSyntax) {
            guard node.declName.baseName.text == "frame",
                let bar = node.base?.as(MemberAccessExprSyntax.self)
                    ?? node.base?.as(OptionalChainingExprSyntax.self)?.expression.as(MemberAccessExprSyntax.self)
                    ?? node.base?.as(ForceUnwrapExprSyntax.self)?.expression.as(MemberAccessExprSyntax.self)
            else {
                return
            }
            if NoLiveUIKitFrameReadsRule.liveBars.contains(bar.declName.baseName.text) {
                found = true
            }
        }
    }
}
