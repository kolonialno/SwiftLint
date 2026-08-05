import SwiftLintCore

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
struct MultilineCallArgumentsRuleExamples {
    static let nonTriggeringExamples: [Example] = #examples([
        // MARK: - Baseline: multi-line OK
        """
            foo(param1: 1,
                param2: false,
                param3: [])
            """.asExample(configuration: ["max_number_of_single_line_parameters": 1]),
        """
            func foo(one: [Int], animated: Bool) {}
            add(one: [
                1,
                2,
                3
            ], animated: true)
            """,
        """
            foo(
                param1: 1,
                param2: 2,
                param3: 3
            )
            """.asExample(configuration: ["allows_single_line": false]),

        // MARK: - Baseline: single-line OK
        "foo(param1: 1, param2: false)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "Enum.foo(param1: 1, param2: false)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // allows_single_line=false does NOT affect 0/1-arg calls
        "foo()".asExample(configuration: ["allows_single_line": false]),
        "foo(param1: 1)".asExample(configuration: ["allows_single_line": false]),
        "Enum.foo(param1: 1)".asExample(configuration: ["allows_single_line": false]),

        // MARK: - Unlabeled / mixed arguments
        "foo(1, 2)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(1, second: 2)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(1, second: 2, third: 3)".asExample(configuration: ["max_number_of_single_line_parameters": 3]),

        // MARK: - Enum-case constructor calls are normal calls (stable by declaring the enum)
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            EnumCase.first(one: 1, two: 2, three: 3, four: 4)
            """.asExample(configuration: ["allows_single_line": true]),
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            let test = EnumCase.first(
                one: 1,
                two: 2,
                three: 3,
                four: 4
            )
            """.asExample(configuration: ["allows_single_line": false]),

        // MARK: - Trailing closures are ignored by this rule (args-only)
        // Single-line args still use max_number_of_single_line_parameters
        """
            foo(first: 1, second: 2) { value in
                print(value)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        // Multi-line args remain valid regardless of closure placement
        """
            foo(
                first: 1,
                second: 2
            ) { value in
                print(value)
            }
            """.asExample(configuration: ["allows_single_line": false]),
        """
            foo(
                first: 1,
                second: 2
            )
            { value in
                print(value)
            }
            """.asExample(configuration: ["allows_single_line": false]),
        // No-parens form: no arguments list -> never violates
        """
            foo { value in
                print(value)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 1]),
        // Multiple trailing closures: still args-only
        """
            foo(first: 1, second: 2) { _ in
                print("main")
            } trailing: { _ in
                print("extra")
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            foo(with: { _ in
                9_999
            }, and: { _ in
                nil
            })
            """,

        // MARK: - Trivia / comments
        """
            foo(
                first: 1,
                // comment
                second: 2,
                third: 3
            )
            """,
        // Note: arguments start on the same line, so this is treated as a single-line-args call;
        // the comma-newline check applies only when argument start lines are already split.
        """
            foo(
                first: (1, 2), second: 3
            )
            """,
        """
            foo(
                first: (1, 2),
                second: 3
            )
            """.asExample(configuration: ["allows_single_line": false]),
        """
            foo(
                first: 1, // comment
                second: 2,
                third: 3
            )
            """,

        """
            enum EnumCase {
                case caseOne(Int, Int, Int, Int)
            }
            let enumCase: EnumCase = .caseOne(
                1,
                2,
                3,
                4
            )
            if case let .caseOne(_, _, three, _) = enumCase {
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            enum EnumCase {
                case caseOne(one: Int, two: Int, three: Int, four: Int)
            }
            let enumCase: EnumCase = .caseOne(
                one: 1,
                two: 2,
                three: 3,
                four: 4
            )
            switch enumCase {
            case let .caseOne(one: _, two: _, three: three, four: _):
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let array: [EnumCase] = [
                .caseOne(
                    1,
                    2,
                    3,
                    4
                )
            ]
            for case let .caseOne(_, _, three, _) in array {
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            enum EnumCase {
                case caseOne(Int, Int, Int, Int)
            }
            let enumCase: EnumCase = .caseOne(
                1,
                2,
                3,
                4
            )
            guard case let .caseOne(_, _, three, _) = enumCase else { return }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            enum EnumCase {
                case caseOne(Int, Int, Int, Int)
            }
            let enumCase: EnumCase = .caseOne(
                1,
                2,
                3,
                4
            )
            while case let .caseOne(_, _, three, _) = enumCase {
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // MARK: - Pattern matching MUST be ignored: catch patterns
        """
            enum EnumCase: Error {
                case caseOne(Int, Int, Int, Int)
            }

            func mayThrow() throws {
            }

            do {
                try mayThrow()
            } catch let EnumCase.caseOne(_, _, three, _) {
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            enum EnumCase: Error {
                case caseOne(one: Int, two: Int, three: Int, four: Int)
            }

            func mayThrow() throws {
            }

            do {
                try mayThrow()
            } catch let EnumCase.caseOne(one: _, two: _, three: three, four: _) {
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // MARK: - Regular calls near patterns are still linted
        """
            func foo(first: Int, second: Int, third: Int) -> Int { a + b + c }
            enum EnumCase { case caseOne(Int, Int, Int, Int) }

            if case let .caseOne(_, _, _, _) = EnumCase.caseOne(
                1,
                2,
                3,
                4
            ) {
                _ = foo(
                    first: 1,
                    second: 2,
                    third: 3
                )
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        // MARK: - Pattern matching MUST be ignored: enum-case patterns with literal subpatterns
        """
            enum EnumCase {
                case caseOne(Int, Int, Int, Int)
            }

            // Real call is written multi-line to avoid noise for max=2
            let enumCase: EnumCase = .caseOne(
                0,
                0,
                0,
                0
            )

            // This is a PATTERN, not a call, and must be ignored even though it looks like `.caseOne(1,2,3,4)`
            if case .caseOne(1, 2, 3, 4) = enumCase {
                // no-op
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        """
            enum EnumCase {
                case caseOne(one: Int, two: Int, three: Int, four: Int)
            }

            let enumCase: EnumCase = .caseOne(
                one: 0,
                two: 0,
                three: 0,
                four: 0
            )

            switch enumCase {
            case .caseOne(one: 1, two: 2, three: 3, four: 4):
                break
            default:
                break
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        """
            enum EnumCase: Error {
                case caseOne(Int, Int, Int, Int)
            }

            func mayThrow() throws {}

            do {
                try mayThrow()
            } catch EnumCase.caseOne(1, 2, 3, 4) {
                // pattern — must be ignored
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            foo(
                // why
                first: 1,
                second: 2
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
        """
            foo(
                first: 1,
                action: {
                    bar()
                }
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
        """
            foo(
                first: 1,
                second: 2
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
    ])

    static let triggeringExamples: [Example] = #examples([
        // MARK: - Single-line: too many args
        "foo(param1: 1, param2: false, ↓param3: [])"
            .asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "Enum.foo(param1: 1, param2: false, ↓param3: [])"
            .asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(1, 2, ↓3)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(1, second: 2, ↓3)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // allows_single_line=false: any 2+ single-line call violates at 2nd argument
        "foo(param1: 1, ↓param2: false)".asExample(configuration: ["allows_single_line": false]),
        "Enum.foo(param1: 1, ↓param2: false)".asExample(configuration: ["allows_single_line": false]),

        // MARK: - Multi-line: two args start on the same line
        """
            foo(
                first: 1, ↓second: 2,
                third: 3
            )
            """,
        """
            foo(
                first: 1,
                second: 2, ↓third: 3
            )
            """,
        """
            foo(
                first: 1,
                second: 2,
                third: 3, ↓fourth: 4,
                fifth: 5
            )
            """,
        """
            foo(
                first: (
                    1,
                    2
                ), ↓second: 3
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 1]),
        """
            foo(
                first: 1, /* comment */ ↓second: 2,
                third: 3
            )
            """,

        // MARK: - Enum-case constructor calls are linted like normal calls
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            EnumCase.first(one: 1, ↓two: 2, three: 3, four: 4)
            """.asExample(configuration: ["allows_single_line": false]),
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            let test = EnumCase.first(one: 1, two: 2, ↓three: 3, four: 4)
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // MARK: - Trailing closure: parentheses args still checked
        """
            foo(first: 1, ↓second: 2) { _ in
                print("x")
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 1]),

        // MARK: - Targeted tests

        // Targeted: real `.caseOne(1,2,3,4)` call MUST be linted (not a pattern)
        """
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let x: EnumCase = .caseOne(1, 2, ↓3, 4)
            _ = x
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: labeled enum-case constructor call MUST be linted
        """
            enum EnumCase {
                case caseOne(one: Int, two: Int, three: Int, four: Int)
            }
            let x: EnumCase = .caseOne(one: 1, two: 2, ↓three: 3, four: 4)
            _ = x
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: pattern-part ignored, RHS call linted
        """
            func foo(first: Int, second: Int, third: Int) -> Int { a + b + c }
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let enumCase: EnumCase = .caseOne(
                1,
                2,
                3,
                4
            )
            if case let .caseOne(_, _, _, _) = enumCase {
                _ = foo(first: 1, second: 2, ↓third: 3)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: switch-where RHS call linted, pattern ignored
        """
            func foo(first: Int, second: Int, third: Int) -> Bool { a + b == c }
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let enumCase: EnumCase = .caseOne(
                1,
                2,
                3,
                4
            )
            switch enumCase {
            case .caseOne where foo(first: 1, second: 2, ↓third: 3):
                break
            default:
                break
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: for-case pattern ignored, body call linted
        """
            func foo(first: Int, second: Int, third: Int) -> Int { a + b + c }
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let array: [EnumCase] = [
                .caseOne(
                    1,
                    2,
                    3,
                    4
                )
            ]
            for case let .caseOne(_, _, _, _) in array {
                _ = foo(first: 1, second: 2, ↓third: 3)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            func foo(first: Int, second: Int, third: Int) -> Int { a + b + c }
            enum EnumCase: Error { case caseOne(Int, Int, Int, Int) }

            func mayThrow() throws {
            }

            do {
                try mayThrow()
            } catch let EnumCase.caseOne(_, _, _, _) {
                _ = foo(first: 1, second: 2, ↓third: 3)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            foo(
                ↓first: 1,
                second: 2
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
    ])

    static let corrections: [Example: Example] = #corrections([
        """
        foo(first: 1, second: 2, third: 3)
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            foo(
                first: 1,
                second: 2,
                third: 3
            )
            """,

        """
        foo(first: 1, second: 2)
        """.asExample(configuration: ["allows_single_line": false]): """
            foo(
                first: 1,
                second: 2
            )
            """,

        // Two arguments are within the allowance, so the call keeps the shape it has.
        """
        foo(first: 1, second: 2)
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            foo(first: 1, second: 2)
            """,

        // A list nested in one being reshaped indents from the line the reshape puts it on, which is what
        // makes the rewrite composable: it can move a list and still lay out what is inside it.
        """
        let row = Row(product: product, quantity: Quantity(value: 1, unit: .piece, isEstimate: false), onTap: onTap)
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            let row = Row(
                product: product,
                quantity: Quantity(
                    value: 1,
                    unit: .piece,
                    isEstimate: false
                ),
                onTap: onTap
            )
            """,

        """
        struct S {
            func f() {
                if condition {
                    return string.boundingRect(with: rect, options: options, attributes: attributes, context: nil)
                }
            }
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            struct S {
                func f() {
                    if condition {
                        return string.boundingRect(
                            with: rect,
                            options: options,
                            attributes: attributes,
                            context: nil
                        )
                    }
                }
            }
            """,

        // The join direction. Both shapes follow from the argument count, so a call that loses an argument
        // comes back to one line instead of keeping the shape it had when it was longer.
        """
        foo(
            first: 1,
            second: 2
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(first: 1, second: 2)
            """,

        // A trailing comma reads as a shape marker only while the list is split.
        """
        foo(
            first: 1,
            second: 2,
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(first: 1, second: 2)
            """,

        // A comment inside the list is a line of its own, so the breaks holding it stay.
        """
        foo(
            // why
            first: 1,
            second: 2
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(
                // why
                first: 1,
                second: 2
            )
            """,

        """
        foo(
            first: 1,
            action: {
                bar()
            }
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(
                first: 1,
                action: {
                    bar()
                }
            )
            """,

        // A single-letter label is a coordinate, and coordinates read as a group rather than as a list.
        """
        CGRect(
            x: 0,
            y: 0,
            width: 24,
            height: 24
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): "CGRect(x: 0, y: 0, width: 24, height: 24)",
        """
        view.shadow(
            color: .black,
            radius: 8,
            y: 2
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): "view.shadow(color: .black, radius: 8, y: 2)",

        // The list that names one, never the list holding it: the outer three still split.
        "Badge(icon: .star, box: CGRect(x: 0, y: 0, width: 8, height: 8), title: name)"
            .asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            Badge(
                icon: .star,
                box: CGRect(x: 0, y: 0, width: 8, height: 8),
                title: name
            )
            """,

        // A join yields to what it contains: joining here would put a call that spans lines on a line it
        // shares with another argument.
        """
        outer(
            first: inner(alpha: 1, beta: 2, gamma: 3),
            second: 2
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            outer(
                first: inner(
                    alpha: 1,
                    beta: 2,
                    gamma: 3
                ),
                second: 2
            )
            """,

        // A multiline string argument means the list already spans lines, so there is no single line to break.
        """
        log(Message(text: \"""
            a
            \""", level: .info), destination: .console)
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            log(Message(text: \"""
                a
                \""", level: .info), destination: .console)
            """,
    ])
}
// swiftlint:enable file_length
