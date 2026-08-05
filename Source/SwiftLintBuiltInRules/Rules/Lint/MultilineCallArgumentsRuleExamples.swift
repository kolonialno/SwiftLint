import SwiftLintCore

// swiftlint:disable file_length

// swiftlint:disable:next type_body_length
struct MultilineCallArgumentsRuleExamples {
    static let nonTriggeringExamples: [Example] = #examples([
        // A computation is not a number, so a list of them stays split however its labels read.
        """
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
        // Nor is an empty array, so a stub stays split rather than being made comfortable.
        """
            make(
                filters: [],
                groups: [],
                selected: 0
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
        // A list of bare numbers is one value spelled out, so it stays on one line at any length.
        """
            CGRect(x: 0, y: 0, width: 24, height: 24)
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            timingCurve(0.4, 0, 0.2, 1, duration: 0.72)
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            insets(top: 0, leading: -8, bottom: 0, trailing: -8)
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
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
                param1: x,
                param2: y,
                param3: z
            )
            """.asExample(configuration: ["allows_single_line": false]),

        // MARK: - Baseline: single-line OK
        "foo(param1: x, param2: false)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "Enum.foo(param1: x, param2: false)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // allows_single_line=false does NOT affect 0/1-arg calls
        "foo()".asExample(configuration: ["allows_single_line": false]),
        "foo(param1: x)".asExample(configuration: ["allows_single_line": false]),
        "Enum.foo(param1: x)".asExample(configuration: ["allows_single_line": false]),

        // MARK: - Unlabeled / mixed arguments
        "foo(x, y)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(x, b: y)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(x, b: y, c: z)".asExample(configuration: ["max_number_of_single_line_parameters": 3]),

        // MARK: - Enum-case constructor calls are normal calls (stable by declaring the enum)
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            EnumCase.first(one: x, two: y, three: z, four: w)
            """.asExample(configuration: ["allows_single_line": true]),
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            let test = EnumCase.first(
                one: x,
                two: y,
                three: z,
                four: w
            )
            """.asExample(configuration: ["allows_single_line": false]),

        // MARK: - Trailing closures are ignored by this rule (args-only)
        // Single-line args still use max_number_of_single_line_parameters
        """
            foo(a: x, b: y) { value in
                print(value)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        // Multi-line args remain valid regardless of closure placement
        """
            foo(
                a: x,
                b: y
            ) { value in
                print(value)
            }
            """.asExample(configuration: ["allows_single_line": false]),
        """
            foo(
                a: x,
                b: y
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
            foo(a: x, b: y) { _ in
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
                a: x,
                // comment
                b: y,
                c: z
            )
            """,
        // Note: arguments start on the same line, so this is treated as a single-line-args call;
        // the comma-newline check applies only when argument start lines are already split.
        """
            foo(
                a: (x, y), b: z
            )
            """,
        """
            foo(
                a: (x, y),
                b: z
            )
            """.asExample(configuration: ["allows_single_line": false]),
        """
            foo(
                a: x, // comment
                b: y,
                c: z
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
                one: x,
                two: y,
                three: z,
                four: w
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
            func foo(a: Int, b: Int, c: Int) -> Int { a + b + c }
            enum EnumCase { case caseOne(Int, Int, Int, Int) }

            if case let .caseOne(_, _, _, _) = EnumCase.caseOne(
                1,
                2,
                3,
                4
            ) {
                _ = foo(
                    a: x,
                    b: y,
                    c: z
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

            // This is a PATTERN, not a call, and must be ignored even though it looks like `.caseOne(x,y,z,w)`
            if case .caseOne(x, y, z, w) = enumCase {
                // no-op
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        """
            enum EnumCase {
                case caseOne(one: Int, two: Int, three: Int, four: Int)
            }

            let enumCase: EnumCase = .caseOne(
                one: q,
                two: q,
                three: q,
                four: q
            )

            switch enumCase {
            case .caseOne(one: x, two: y, three: z, four: w):
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
            } catch EnumCase.caseOne(x, y, z, w) {
                // pattern — must be ignored
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            foo(
                // why
                a: x,
                b: y
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
        """
            foo(
                a: x,
                action: {
                    bar()
                }
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
        """
            foo(
                a: x,
                b: y
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
    ])

    static let triggeringExamples: [Example] = #examples([
        // MARK: - Single-line: too many args
        "foo(param1: x, param2: false, ↓param3: [])"
            .asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "Enum.foo(param1: x, param2: false, ↓param3: [])"
            .asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(x, y, ↓3)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        "foo(x, b: y, ↓3)".asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // allows_single_line=false: any 2+ single-line call violates at 2nd argument
        "foo(param1: x, ↓param2: false)".asExample(configuration: ["allows_single_line": false]),
        "Enum.foo(param1: x, ↓param2: false)".asExample(configuration: ["allows_single_line": false]),

        // MARK: - Multi-line: two args start on the same line
        """
            foo(
                a: x, ↓b: y,
                c: z
            )
            """,
        """
            foo(
                a: x,
                b: y, ↓c: z
            )
            """,
        """
            foo(
                a: x,
                b: y,
                c: z, ↓d: w,
                e: v
            )
            """,
        """
            foo(
                a: (
                    1,
                    2
                ), ↓b: z
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 1]),
        """
            foo(
                a: x, /* comment */ ↓b: y,
                c: z
            )
            """,

        // MARK: - Enum-case constructor calls are linted like normal calls
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            EnumCase.first(one: x, ↓two: y, three: z, four: w)
            """.asExample(configuration: ["allows_single_line": false]),
        """
            enum EnumCase {
                case first(one: Int, two: Int, three: Int, four: Int)
            }
            let test = EnumCase.first(one: x, two: y, ↓three: z, four: w)
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // MARK: - Trailing closure: parentheses args still checked
        """
            foo(a: x, ↓b: y) { _ in
                print("x")
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 1]),

        // MARK: - Targeted tests

        // Targeted: real `.caseOne(x,y,z,w)` call MUST be linted (not a pattern)
        """
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let x: EnumCase = .caseOne(x, y, ↓3, w)
            _ = x
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: labeled enum-case constructor call MUST be linted
        """
            enum EnumCase {
                case caseOne(one: Int, two: Int, three: Int, four: Int)
            }
            let x: EnumCase = .caseOne(one: x, two: y, ↓three: z, four: w)
            _ = x
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: pattern-part ignored, RHS call linted
        """
            func foo(a: Int, b: Int, c: Int) -> Int { a + b + c }
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let enumCase: EnumCase = .caseOne(
                1,
                2,
                3,
                4
            )
            if case let .caseOne(_, _, _, _) = enumCase {
                _ = foo(a: x, b: y, ↓c: z)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: switch-where RHS call linted, pattern ignored
        """
            func foo(a: Int, b: Int, c: Int) -> Bool { a + b == c }
            enum EnumCase { case caseOne(Int, Int, Int, Int) }
            let enumCase: EnumCase = .caseOne(
                1,
                2,
                3,
                4
            )
            switch enumCase {
            case .caseOne where foo(a: x, b: y, ↓c: z):
                break
            default:
                break
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),

        // Targeted: for-case pattern ignored, body call linted
        """
            func foo(a: Int, b: Int, c: Int) -> Int { a + b + c }
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
                _ = foo(a: x, b: y, ↓c: z)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            func foo(a: Int, b: Int, c: Int) -> Int { a + b + c }
            enum EnumCase: Error { case caseOne(Int, Int, Int, Int) }

            func mayThrow() throws {
            }

            do {
                try mayThrow()
            } catch let EnumCase.caseOne(_, _, _, _) {
                _ = foo(a: x, b: y, ↓c: z)
            }
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
            foo(
                ↓a: x,
                b: y
            )
            """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
    ])

    static let corrections: [Example: Example] = #corrections([
        // A split list of bare numbers comes back to one line, however many of them there are, and takes the
        // call that holds it back with it.
        """
        CGRect(
            x: 0,
            y: 0,
            width: 24,
            height: 24
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            CGRect(x: 0, y: 0, width: 24, height: 24)
            """,

        """
        fill(
            CGRect(
                x: 0,
                y: 0,
                width: 1,
                height: 1
            )
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            """,

        """
        foo(a: x, b: y, c: z)
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            foo(
                a: x,
                b: y,
                c: z
            )
            """,

        """
        foo(a: x, b: y)
        """.asExample(configuration: ["allows_single_line": false]): """
            foo(
                a: x,
                b: y
            )
            """,

        // Two arguments are within the allowance, so the call keeps the shape it has.
        """
        foo(a: x, b: y)
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            foo(a: x, b: y)
            """,

        // A list nested in one being reshaped indents from the line the reshape puts it on, which is what
        // makes the rewrite composable: it can move a list and still lay out what is inside it.
        """
        let row = Row(product: product, quantity: Quantity(value: x, unit: .piece, isEstimate: false), onTap: onTap)
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            let row = Row(
                product: product,
                quantity: Quantity(
                    value: x,
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
            a: x,
            b: y
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(a: x, b: y)
            """,

        // A trailing comma reads as a shape marker only while the list is split.
        """
        foo(
            a: x,
            b: y,
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(a: x, b: y)
            """,

        // A comment inside the list is a line of its own, so the breaks holding it stay.
        """
        foo(
            // why
            a: x,
            b: y
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(
                // why
                a: x,
                b: y
            )
            """,

        """
        foo(
            a: x,
            action: {
                bar()
            }
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            foo(
                a: x,
                action: {
                    bar()
                }
            )
            """,

        // A join yields to what it contains: joining here would put a call that spans lines on a line it
        // shares with another argument.
        """
        outer(
            a: inner(x: x, y: y, z: z),
            b: y
        )
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            outer(
                a: inner(
                    x: x,
                    y: y,
                    z: z
                ),
                b: y
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
