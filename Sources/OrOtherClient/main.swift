import OrOther

@OrOther<String>
private enum EnumTest {
    private enum Options: String {
        case a
        case b
        case c, dfjdf, flahfeo, ldjfl
    }
}

//extension EventType: Hashable {
//}

//let a: EventType = .other(<#T##String#>)

