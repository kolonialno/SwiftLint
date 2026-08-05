import SwiftBasicFormat
import SwiftLintCore
import SwiftSyntax

/// How many elements a comma-separated list may keep on one line.
///
/// Shared by the rules that give the same shape to different lists — call arguments, declaration
/// parameters, conditions — so the threshold means one thing across all of them.
protocol SingleLineAllowance {
    var allowsSingleLine: Bool { get }
    var maxNumberOfSingleLineParameters: Int? { get }

    /// Whether a list within the allowance must be on one line, which is the shape's other direction:
    /// adding an element splits the list and removing one joins it again, so the shape follows from the
    /// element count rather than from the list's history.
    var requiresSingleLine: Bool { get }
}

extension SyntaxCollection where Element: WithTrailingCommaSyntax {
    /// Read from trivia rather than from source locations, because a rewrite moves everything after it and
    /// the location converter still answers from the file as it was read. A list nested in one that has
    /// already been reshaped is exactly the case that matters, and locations there are stale.
    var isOnOneLine: Bool {
        tokens(viewMode: .sourceAccurate).allSatisfy { token in
            !token.leadingTrivia.containsNewline
                && !token.trailingTrivia.containsNewline
                && !token.text.contains("\n")
        }
    }

    func exceedsSingleLineAllowance(_ allowance: some SingleLineAllowance) -> Bool {
        if !allowance.allowsSingleLine {
            return true
        }
        if readsAsOneValue {
            return false
        }
        guard let maximum = allowance.maxNumberOfSingleLineParameters else {
            return false
        }
        return count > maximum
    }

    /// Whether any element names itself with a single letter.
    ///
    /// `x`, `y`, `r` are coordinates, and coordinates are read as a group: stacking them vertically hides the
    /// shape they describe, so one of them keeps the whole list on one line whatever its length —
    /// `CGRect(x: 0, y: 0, width: 24, height: 24)`, `shadow(color: .black, radius: 8, y: 2)`. It applies to
    /// the list that names one, never to a list containing it, so an argument that happens to be a rectangle
    /// does not flatten its parent.
    /// Whether this list describes one value rather than a set of arguments, in which case it is horizontal
    /// at any length. Both directions and both halves of every rule ask this one question.
    var readsAsOneValue: Bool {
        namesACoordinate || namesOnlyComponents
    }

    /// Whether every element names a component of one value.
    ///
    /// `Color(red: 1, green: 0, blue: 0)` and `EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)` are read
    /// as one thing for the same reason coordinates are, and the single-letter test misses them because their
    /// labels are words. This is the one exception that needs a list of names, so the list is closed and short:
    /// a label earns a place by being a *part of a value* rather than a thing in its own right. Every element
    /// has to be one, so a call that names a colour channel among real arguments still splits.
    var namesOnlyComponents: Bool {
        guard count > 1 else {
            return false
        }
        return allSatisfy { element in
            let syntax = Syntax(element)
            let name =
                syntax.as(LabeledExprSyntax.self)?.label?.text
                ?? syntax.as(FunctionParameterSyntax.self)?.firstName.text
            guard let name else {
                return false
            }
            return componentLabels.contains(name)
        }
    }

    var namesACoordinate: Bool {
        contains { element in
            let syntax = Syntax(element)
            let name =
                syntax.as(LabeledExprSyntax.self)?.label?.text
                ?? syntax.as(FunctionParameterSyntax.self)?.firstName.text
            guard let name, name.count == 1, let letter = name.first, letter.isLetter else {
                return false
            }
            return true
        }
    }

    /// Whether the breaks in this list hold nothing a join would destroy — no comment to lose, no closure
    /// body, no multiline string — since a join only takes back the breaks these rules would have made.
    ///
    /// The list's closing token is the caller's to check: a condition list has none.
    var canRejoinOneLine: Bool {
        allSatisfy { element in
            !element.trimmedDescription.contains("\n")
                && !element.leadingTrivia.containsComment
                && !element.trailingTrivia.containsComment
        }
    }

    /// Whether a comment sits anywhere among the elements. A reshape writes the shape into the very trivia
    /// the comment lives in, so it would be dropped — which makes this the one thing that stops a split.
    var containsComment: Bool {
        tokens(viewMode: .sourceAccurate).contains { token in
            token.leadingTrivia.containsComment || token.trailingTrivia.containsComment
        }
    }

    /// Whether the list is split across lines but keeps more than one element on some line, which is the
    /// shape that is neither one line nor one per line. A first element sharing the opening line is not that:
    /// every element still has a line of its own.
    var isSplitUnevenly: Bool {
        !isOnOneLine && dropFirst().contains { !$0.leadingTrivia.containsNewline }
    }

    /// Whether the first element shares its opener's line while every later element has one of its own,
    /// which is the split shape for a list opened by a keyword rather than by a delimiter.
    var isSplitAfterTheFirst: Bool {
        guard let first else {
            return true
        }
        return !first.leadingTrivia.containsNewline
            && dropFirst().allSatisfy(\.leadingTrivia.containsNewline)
    }

    /// One element per line, each a level in from the line the list's owner starts on.
    ///
    /// Writing the shape out in full rather than inserting a single break is what lets a formatter run
    /// afterwards: hand one half a shape and it resolves the rest its own way, which is how a corrector and
    /// a formatter end up trading the same edit forever.
    func splitOnePerLine(from indentation: Trivia) -> Self {
        Self(
            map { element in
                element
                    .with(\.leadingTrivia, .newline + indentation + .spaces(4))
                    .with(\.trailingTrivia, [])
            }
        )
    }

    /// The first element left on its opener's line and the rest one per line.
    ///
    /// A list opened by a keyword cannot break after the opener: swift-format pulls a lone `if` or `while`
    /// back down onto its first condition whatever break it finds there, and no setting turns that off
    /// (`lineBreakBeforeControlFlowKeywords` governs `else` and `catch`). Observed against swift-format from
    /// Xcode 26 on 2026-08-04, with `respectsExistingLineBreaks` on. So the break goes after the first
    /// element, which is a shape it does leave alone.
    func splitAfterTheFirst(from indentation: Trivia) -> Self {
        Self(
            enumerated().map { index, element in
                element
                    .with(\.leadingTrivia, index == 0 ? [] : .newline + indentation + .spaces(4))
                    .with(\.trailingTrivia, [])
            }
        )
    }

    /// Every element back on one line, the first of them separated from its opener by `leadingTrivia` —
    /// nothing after a delimiter, a space after a keyword.
    func joinedOnOneLine(startingWith leadingTrivia: Trivia) -> Self {
        let last = count - 1
        return Self(
            enumerated().map { index, element in
                // A trailing comma on the last element reads as a shape marker only while the list is split;
                // on one line it is noise, so the join drops it.
                let comma = index == last
                    ? nil
                    : element.trailingComma?.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
                return element
                    .with(\.leadingTrivia, index == 0 ? leadingTrivia : .space)
                    .with(\.trailingTrivia, [])
                    .with(\.trailingComma, comma)
            }
        )
    }
}

extension SyntaxProtocol {
    /// The indentation of the line this node starts on, read from the tree so it survives a rewrite.
    var indentationOfOwnLine: Trivia {
        firstToken(viewMode: .sourceAccurate)?.indentationOfLine ?? []
    }
}

extension Trivia {
    var containsNewline: Bool {
        contains(where: \.isNewline)
    }

    var containsComment: Bool {
        contains(where: \.isComment)
    }
}


/// Labels that name a part of one value rather than an argument in its own right.
private let componentLabels: Set<String> = [
    "red", "green", "blue", "opacity", "alpha", "white", "hue", "saturation", "brightness",
    "top", "leading", "bottom", "trailing", "left", "right", "horizontal", "vertical",
    "width", "height", "minimum", "maximum",
]
