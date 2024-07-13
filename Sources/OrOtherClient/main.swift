import OrOther

@OrOther/*<String>*/
private enum EnumTest: RawRepresentable {
    private enum Options: String {
        case a
        case b
        case c, dfjdf, flahfeo, ldjfl
    }
}

//let a: EnumTest = .other(<#T##String#>)
