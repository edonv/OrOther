# OrOther

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FOrOther%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/edonv/OrOther)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fedonv%2FOrOther%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/edonv/OrOther)

`OrOther` is a macro that adds a "blank" `.other(_:)` case to any enum. All that's needed is to create an empty enum, add a `private` nested enum called `Options` with an explicit raw value type, add the explicit cases you want, then tack `@OrOther` onto the primary enum.

`OrOther` will automatically synthesize the any enum cases you add to `Options`, then add an extra `.other(_:)` case. The `.other(_:)` case has an associated value of the same type as the `Options` enum's raw value.

It also automatically synthesizes conformace to `RawRepresentable` for the attached enum, by adding a synthesized computed `rawValue` property and `init(rawValue:)` initializer:
- `rawValue` returns the `rawValue` of the matching case from the nested `Options` enum, unless it's `.other`, in which case, the associated value is returned.
- `init(rawValue:)` is *non-failable*, as it first tries to match the `rawValue` to that of the `Options` enum and return the matching case. If there isn't a matching case in `Options`, it returns `rawValue` as the associated value of an `.other` case.

## Example

### Usage

```swift
@OrOther
enum EnumTest {
    private enum Options: String {
        case a
        case b
        case c, dfjdf, flahfeo, ldjfl
    }
}
```

### Synthesized Output

```swift
enum EnumTest {
    private enum Options: String { ... }
    
    typealias RawValue = String

    case a, b, c, dfjdf, flahfeo, ldjfl, other(String)

    var rawValue: RawValue {
        switch self {
        case .a:
            return Options.a.rawValue
        case .b:
            return Options.b.rawValue
        case .c:
            return Options.c.rawValue
        case .dfjdf:
            return Options.dfjdf.rawValue
        case .flahfeo:
            return Options.flahfeo.rawValue
        case .ldjfl:
            return Options.ldjfl.rawValue
        case .other(let string):
            return string
        }
    }

    init(rawValue: RawValue) {
        if let this = Options(rawValue: rawValue) {
            switch this {
            case .a:
                self = .a
            case .b:
                self = .b
            case .c:
                self = .c
            case .dfjdf:
                self = .dfjdf
            case .flahfeo:
                self = .flahfeo
            case .ldjfl:
                self = .ldjfl
            }
        } else {
            self = .other(rawValue)
        }
    }
}
```
