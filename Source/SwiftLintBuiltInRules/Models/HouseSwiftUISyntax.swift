import SwiftSyntax

extension KeyPathExprSyntax {
    /// The property `\.foo` names, or `nil` for a path with a root or more than one component.
    var singlePropertyName: String? {
        guard root == nil,
            components.count == 1,
            case let .property(property) = components.first?.component
        else {
            return nil
        }
        return property.declName.baseName.text
    }
}

extension AttributeSyntax {
    /// The environment key `@Environment(\.foo)` reads, or `nil` for any other attribute.
    var environmentKeyRead: String? {
        guard attributeName.trimmedDescription == "Environment",
            case let .argumentList(arguments) = arguments,
            let keyPath = arguments.onlyElement?.expression.as(KeyPathExprSyntax.self)
        else {
            return nil
        }
        return keyPath.singlePropertyName
    }
}

extension FunctionCallExprSyntax {
    /// The name of the member being called, for `foo.bar(…)` and `.bar(…)` alike.
    var calledMemberName: String? {
        calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    }

    /// The position of the `.` in `.bar(…)`, which is where these rules report.
    var calledMemberPeriodPosition: AbsolutePosition? {
        calledExpression.as(MemberAccessExprSyntax.self)?.period.positionAfterSkippingLeadingTrivia
    }

    var firstArgumentLabel: String? {
        arguments.first?.label?.text
    }

    /// The environment key `.environment(\.foo, …)` writes, or `nil` for any other call.
    var environmentKeyWritten: String? {
        guard calledMemberName == "environment",
            let keyPath = arguments.first?.expression.as(KeyPathExprSyntax.self)
        else {
            return nil
        }
        return keyPath.singlePropertyName
    }
}
