/// A type describing the SwiftLint version.
public struct Version: VersionComparable, Sendable {
    /// The string value for this version.
    public let value: String

    /// An alias for `value` required for protocol conformance.
    public var rawValue: String {
        value
    }

    /// The current SwiftLint version.
    /// Suffixed because a consumer asserts the linter it runs is the one the repo pins, and a fork that
    /// reports an upstream version cannot be told apart from an upstream build of it.
    public static let current = Self(value: "0.65.0-oda.10")

    /// Public initializer.
    ///
    /// - parameter value: The string value for this version.
    public init(value: String) {
        self.value = value
    }
}
