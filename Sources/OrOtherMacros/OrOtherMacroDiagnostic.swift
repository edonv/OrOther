//
//  OrOtherMacroDiagnostic.swift
//  
//
//  Created by Edon Valdman on 2/22/24.
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax

enum OrOtherMacroDiagnostic {
    case requiresEnum
    case requiresEnum1RawType
    case requiresOptionsEnum
    case requiresOptionsEnumRawType
    case requiresRawTypesMatch
    case requiresOptionsPrivateEnum
    case requiresOptionsNonEmptyEnum
}

extension OrOtherMacroDiagnostic: DiagnosticMessage {
    func diagnose<Node: SyntaxProtocol>(at node: Node) -> Diagnostic {
        Diagnostic(node: Syntax(node), message: self)
    }
    
    var message: String {
        switch self {
        case .requiresEnum:
            return "'OrOther' macro can only be applied to an enum"
            
        case .requiresEnum1RawType:
            return "'OrOther' macro requires 1 raw type"
            
        case .requiresOptionsEnum:
            return "'OrOther' macro requires nested options enum 'Options'"
            
        case .requiresOptionsEnumRawType:
            return "'OrOther' macro requires nested enum 'Options' have a raw type"
        
        case .requiresRawTypesMatch:
            return "'OrOther' macro requires that it and 'Options' have matching raw types"
            
        case .requiresOptionsPrivateEnum:
            return "'OrOther' macro requires nested enum 'Options' be 'private'"
            
        case .requiresOptionsNonEmptyEnum:
            return "'OrOther' macro requires nested enum 'Options' have at least one case"
            
            
        }
    }
    
    var severity: DiagnosticSeverity { .error }
    
    var diagnosticID: MessageID {
        MessageID(domain: "Swift", id: "OrOther.\(self)")
    }
}
