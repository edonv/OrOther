/// A macro that generates additional members of the attached enum `RawRepresentable` enum from a nested `private` `Options` enum, adding an `.other(_:)` case. The `.other(_:)` case has an associated value of the same type as the `Options` enum's raw value. produces both a value and a string containing the
/// source code that generated the value.
///
/// It adds a synthesized computed `rawValue` property and `init(rawValue:)` initializer.
///
/// `rawValue` returns the `rawValue` of the matching case from the nested `Options` enum, unless it's `.other`, in which case, the associated value is returned.
///
/// `init(rawValue:)` can't fail, as it tried to match the `rawValue` to that of the `Options` enum, and return the matching case. If there isn't a matching case, it returns the value inside an `.other` case.
///
/// ## Example
///
/// ```swift
/// @OrOther<String>
/// private enum EnumTest {
///     private enum Options: String {
///         case a
///         case b
///         case c, dfjdf, flahfeo, ldjfl
///     }
/// }
/// ```
@attached(extension, conformances: RawRepresentable, Equatable, Hashable)
@attached(member, names: named(RawValue), named(rawValue), named(`init`), arbitrary)
public macro OrOther<RawType>() =
    #externalMacro(module: "OrOtherMacros", type: "OrOtherMacro")
