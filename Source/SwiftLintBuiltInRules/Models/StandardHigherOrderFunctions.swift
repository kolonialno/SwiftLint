import SwiftSyntax

/// The standard-library functions taking a single closure that a key path can be coerced into, with the
/// argument label each expects.
///
/// `prefer_key_path` and `key_path_only_where_the_api_takes_one` enforce opposite conventions over exactly
/// this set, so they read one list: adding a function serves both, and they can never drift apart.
let argumentLabelByStandardFunction: [String: String?] = [
    "allSatisfy": nil,
    "contains": "where",
    "compactMap": nil,
    "drop": "while",
    "filter": nil,
    "first": "where",
    "firstIndex": "where",
    "flatMap": nil,
    "forEach": nil,
    "last": "where",
    "map": nil,
    "partition": "by",
    "prefix": "while",
    "removeAll": "where",
]

extension FunctionCallExprSyntax {
    var isStandardFunction: Bool {
        if let calleeName, argumentLabelByStandardFunction.keys.contains(calleeName) {
            return arguments.count + (trailingClosure == nil ? 0 : 1) == 1
        }
        return false
    }

    var calleeName: String? {
        (calledExpression.as(DeclReferenceExprSyntax.self)
            ?? calledExpression.as(MemberAccessExprSyntax.self)?.declName)?.baseName.text
    }

    /// The `\.foo` this call passes where a closure is expected, which is the coercion the house style bans.
    var coercedKeyPath: KeyPathExprSyntax? {
        guard let calleeName,
            let expectedLabel = argumentLabelByStandardFunction[calleeName],
            trailingClosure == nil,
            let argument = arguments.onlyElement,
            argument.label?.text == expectedLabel,
            let keyPath = argument.expression.as(KeyPathExprSyntax.self),
            keyPath.root == nil
        else {
            return nil
        }
        return keyPath
    }
}
