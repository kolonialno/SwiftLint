import Foundation
import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(explicitRewriter: true, optIn: true)
struct GroupedImportsRule: Rule {
    var configuration = GroupedImportsConfiguration()

    static let description = RuleDescription(
        identifier: "grouped_imports",
        name: "Grouped Imports",
        description: """
            Imports go in three groups — Apple's frameworks, then the project's own modules, then \
            third-party ones — alphabetically within a group and with no blank line between groups
            """,
        kind: .style,
        nonTriggeringExamples: #examples([
            """
            import Foundation
            import SwiftUI
            import Alamofire
            """,
            """
            import Foundation

            struct Model {}
            """,
            """
            // A header comment stays put.
            import UIKit
            import Alamofire
            """,
            """
            import Alamofire
            // A comment ends the run, so what follows is a run of its own.
            import Foundation
            import UIKit
            """,
            "import Foundation",
            """
            @testable import XCTest
            import SwiftUI
            """,
        ]) + [
            """
            import UIKit
            import KolibriKit
            import Alamofire
            """.asExample(configuration: ourModules),
            """
            import XCTest
            @testable import OdaiOS
            """.asExample(configuration: ourModules),
        ],
        triggeringExamples: #examples([
            """
            ↓import SwiftUI
            import Foundation
            """,
            """
            ↓import Alamofire
            import UIKit
            """,
            """
            import Foundation
            import UIKit
            ↓import Foundation
            """,
        ]) + [
            """
            ↓import KolibriKit
            import UIKit
            """.asExample(configuration: ourModules),
            """
            ↓import Alamofire
            import KolibriKit
            """.asExample(configuration: ourModules),
        ],
        corrections: #corrections([
            "import SwiftUI\nimport Foundation": "import Foundation\nimport SwiftUI",
            "import Alamofire\nimport UIKit": "import UIKit\nimport Alamofire",
            "import Foundation\nimport UIKit\nimport Foundation": "import Foundation\nimport UIKit",
            "import Foundation\n\nimport Alamofire\nimport UIKit":
                "import Foundation\n\nimport UIKit\nimport Alamofire",
            "import Alamofire\n@testable import XCTest": "@testable import XCTest\nimport Alamofire",
        ])
    )

    /// A package manifest is left alone. Its first line has to be the `swift-tools-version` comment or
    /// SwiftPM cannot read the file at all, which makes reordering the imports underneath it the one place
    /// where getting the trivia wrong stops a package from building rather than merely reading oddly. There
    /// is nothing to gain either way: a manifest imports `PackageDescription` and occasionally one more.
    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        namesAPackageManifest(file) ? nil : file.syntaxTree
    }

    private func namesAPackageManifest(_ file: SwiftLintFile) -> Bool {
        guard let name = file.path?.lastPathComponent else {
            return false
        }
        return name == "Package.swift" || (name.hasPrefix("Package@swift-") && name.hasSuffix(".swift"))
    }
}

/// The project's own modules, for the examples that need a middle group to sort into.
private let ourModules: [String: any Sendable] = ["our_modules": ["KolibriKit", "OdaiOS"]]

private extension GroupedImportsRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: CodeBlockItemListSyntax) {
            for run in node.importRuns(ourModules: configuration.ourModules) {
                guard let misplaced = run.firstOutOfPlace else {
                    continue
                }
                violations.append(misplaced.position)
            }
        }
    }

    final class Rewriter: ViolationsSyntaxRewriter<ConfigurationType> {
        override func visit(_ node: CodeBlockItemListSyntax) -> CodeBlockItemListSyntax {
            let runs = node.importRuns(ourModules: configuration.ourModules)
                .filter { $0.firstOutOfPlace != nil }
            guard runs.isNotEmpty else {
                return super.visit(node)
            }

            var items = Array(node)
            var dropped: Set<Int> = []
            for run in runs {
                let wanted = run.grouped
                var declarations: [String: ImportDeclSyntax] = [:]
                for line in run {
                    declarations[line.text] = line.declaration
                }
                for (offset, line) in run.enumerated() {
                    guard offset < wanted.count, let declaration = declarations[wanted[offset]] else {
                        dropped.insert(line.index)
                        continue
                    }
                    // The slot keeps its own trivia, so a run's surrounding blank lines do not travel
                    // with the import that moves into it.
                    var moved = declaration.trimmed
                    moved.leadingTrivia = items[line.index].leadingTrivia
                    moved.trailingTrivia = items[line.index].trailingTrivia
                    items[line.index] = CodeBlockItemSyntax(item: .decl(DeclSyntax(moved)))
                }
                numberOfCorrections += 1
            }

            let regrouped = items.enumerated()
                .filter { !dropped.contains($0.offset) }
                .map(\.element)
            return super.visit(CodeBlockItemListSyntax(regrouped))
        }
    }
}
