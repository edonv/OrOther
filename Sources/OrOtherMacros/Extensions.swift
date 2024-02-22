//
//  Extensions.swift
//
//
//  Created by Edon Valdman on 2/22/24.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

extension SyntaxStringInterpolation {
    mutating func appendInterpolation<Node: SyntaxProtocol>(_ node: Node?) {
        if let node = node {
            appendInterpolation(node)
        }
    }
}

extension DeclModifierSyntax {
    var isPrivateAccessLevelModifier: Bool {
        switch self.name.tokenKind {
        case .keyword(.private): return true
        default: return false
        }
    }
    
    var isAccessLevelModifier: Bool {
        guard case .keyword(let keyword) = self.name.tokenKind else { return false }
        return [
            .public,
//            .private,
//            .fileprivate,
//            .internal,
//            .open,
            .package
        ].contains(keyword)
    }
}
