import SwiftLintCore

internal struct MultilineConditionsRuleExamples {
    static let nonTriggeringExamples: [Example] = #examples([
        "if a { }",
        "if a, b { }",
        "guard a else { return }",
        "guard a, b else { return }",
        "while a, b { }",
        """
        if a, b, c { }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 3]),
        """
        if a,
            b,
            c
        {
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
        guard a,
            b,
            c
        else {
            return
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
        guard a,
            b
        else {
            return
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        // A lone condition that spans lines has nothing to align against, so the keyword keeps its own line.
        """
        guard
            let path = search(
                directory,
                .userDomainMask,
                true
            ).first
        else {
            return
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
    ])

    static let triggeringExamples: [Example] = #examples([
        """
        if ↓a, b, c { }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
        guard ↓a, b, c else { return }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
        while ↓a, b, c { }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
        if ↓a, b,
            c
        {
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]),
        """
        guard ↓a,
            b
        else {
            return
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]),
    ])

    static let corrections: [Example: Example] = #corrections([
        """
        if a, b, c { }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            if a,
                b,
                c
            { }
            """,

        """
        guard a, b, c else { return }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            guard a,
                b,
                c
            else { return }
            """,

        """
        while a, b, c { }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            while a,
                b,
                c
            { }
            """,

        // The break goes after the first condition, never after the keyword: swift-format pulls a lone `if`
        // back down onto its first condition, so a shape that broke there could not survive it.
        """
        if
            a,
            b,
            c
        {
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            if a,
                b,
                c
            {
            }
            """,

        // Neither one line nor one per line after the first.
        """
        if a, b,
            c
        {
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            if a,
                b,
                c
            {
            }
            """,

        // The join direction: a condition list that loses a clause comes back to one line.
        """
        guard a,
            b
        else {
            return
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            guard a, b else {
                return
            }
            """,

        // A comment between the conditions is a line of its own, so the breaks holding it stay.
        """
        guard a,
            // why b
            b
        else {
            return
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2, "requires_single_line": true]): """
            guard a,
                // why b
                b
            else {
                return
            }
            """,

        """
        struct S {
            func f() {
                guard a, b, c else { return }
            }
        }
        """.asExample(configuration: ["max_number_of_single_line_parameters": 2]): """
            struct S {
                func f() {
                    guard a,
                        b,
                        c
                    else { return }
                }
            }
            """,
    ])
}
