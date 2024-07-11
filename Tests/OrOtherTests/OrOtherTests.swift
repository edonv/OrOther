import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(OrOtherMacros)
import OrOtherMacros
import OrOther

final class OrOtherTests: XCTestCase {
    @OrOther
    private enum EnumTest: RawRepresentable, Codable, CaseIterable {
        static let allCases: [Self] = [.a, .b, .c, .d, .e, .f]
        
        private enum Options: String {
            case a
            case b
            case c, d, e, f
        }
    }
    
    private struct StructTest: Codable {
        let option: EnumTest
        let string: String
    }
    
    func testMacro() throws {
        let array: [EnumTest] = [.a, .b, .d, .f, .other("YES")]
        let data = try JSONEncoder().encode(array)
        print("array:", String(data: data, encoding: .utf8))
        
        let test = StructTest(option: .c, string: "STRING")
        let dataTest = try JSONEncoder().encode(test)
        print("struct:", String(data: dataTest, encoding: .utf8))
        let decoded = try JSONDecoder().decode(StructTest.self, from: dataTest)
        print("struct decoded:", decoded.option)
    }
}
#endif
