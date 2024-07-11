import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - MemberMacro
public struct OrOtherMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Make sure it's attached to an enum
        guard declaration.is(EnumDeclSyntax.self) else {
            context.diagnose(OrOtherMacroDiagnostic.requiresEnum.diagnose(at: declaration))
            return []
        }
        
        // Make sure the primary enum is *not* private (or else it can't add the RawRepresentable extension).
        // If the declaration already includes explicit conformance to RawRepresentable, it lets it slide.
        // This is because it can't generate an extension to add RawRepresentable conformance to a private type.
        guard !declaration.modifiers.contains(where: \.isPrivateAccessLevelModifier)
                || (declaration.inheritanceClause?.inheritedTypes ?? []).containsType(withName: "RawRepresentable") else {
            context.diagnose(OrOtherMacroDiagnostic.requiresEnumNotPrivateOrExplicitRawRep.diagnose(at: declaration))
            return []
        }
        
        // Parse the first nested member as an enum named Options
        guard let optionEnumDecl = declaration.memberBlock.members.compactMap({ $0.decl.as(EnumDeclSyntax.self) }).first else {
            context.diagnose(OrOtherMacroDiagnostic.requiresOptionsEnum.diagnose(at: declaration))
            return []
        }
        
        // Make sure it's a private enum
        guard optionEnumDecl.modifiers.contains(where: \.isPrivateAccessLevelModifier) else {
            context.diagnose(OrOtherMacroDiagnostic.requiresOptionsPrivateEnum.diagnose(at: declaration))
            return []
        }
        
//        // Extract exactly 1 generic type from enum,
//        guard let genericClause = node.attributeName.as(IdentifierTypeSyntax.self)?.genericArgumentClause,
//              genericClause.arguments.count == 1,
//              let rawType = genericClause.arguments.first?.argument else {
//            context.diagnose(OrOtherMacroDiagnostic.requiresEnum1RawType.diagnose(at: node))
//            return []
//        }
        
        // RawValue type from Options enum,
        guard let optionsRawType = optionEnumDecl.inheritanceClause?.inheritedTypes.first?.type else {
            context.diagnose(OrOtherMacroDiagnostic.requiresOptionsEnumRawType.diagnose(at: node))
            return []
        }
        
//        // ...and make sure they match
//        guard case .identifier(let genericTypeName) = rawType.as(IdentifierTypeSyntax.self)?.name.tokenKind,
//              case .identifier(let optionsRawTypeName) = optionsRawType.as(IdentifierTypeSyntax.self)?.name.tokenKind,
//              genericTypeName == optionsRawTypeName else {
//            context.diagnose(OrOtherMacroDiagnostic.requiresRawTypesMatch.diagnose(at: node))
//            return []
//        }
        
        // Make sure it has at least one case
        let optionEnumCaseElements: [EnumCaseElementSyntax] = optionEnumDecl.memberBlock.members
            .compactMap { member in
                member.decl.as(EnumCaseDeclSyntax.self)?.elements
            }
            .flatMap { $0 }
        guard !optionEnumCaseElements.isEmpty else {
            context.diagnose(OrOtherMacroDiagnostic.requiresOptionsNonEmptyEnum.diagnose(at: declaration))
            return []
        }
        
        // Get access control keyword from primary declaration
        let access = declaration.modifiers.first(where: \.isAccessLevelModifier)
        
        // MARK: - CaseIterable
        
        let allCases: DeclSyntax?
        let isCaseIterable = (declaration.inheritanceClause?.inheritedTypes ?? []).containsType(withName: "CaseIterable")
        let containsAllCases = declaration.memberBlock.members.contains { memberItem in
            guard let varDecl = memberItem.decl.as(VariableDeclSyntax.self),
                  varDecl.modifiers.contains(where: { $0.name.trimmedDescription == "static" })
                    && varDecl.bindings.contains(where: {
                        $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmedDescription == "allCases"
                    }) else { return false }
            return true
        }
        
        if isCaseIterable
            && !containsAllCases {
            let enumCases = optionEnumCaseElements
                .map(\.name.trimmedDescription)
                .map { ".\($0)" }
            allCases = "\(access)static let allCases: [Self] = [\(raw: enumCases.joined(separator: ", "))]"
        } else {
            allCases = nil
        }
        
        // typealias
        let rawValueTypeAliasDecl: DeclSyntax = "\(access)typealias RawValue = \(optionsRawType)"
        
        // cases
        let casesDecl = EnumCaseDeclSyntax {
            for enumCase in optionEnumCaseElements {
                EnumCaseElementSyntax(name: enumCase.name.trimmed)
            }
            
            EnumCaseElementSyntax(
                name: .identifier("other"),
                parameterClause: .init(parameters: [.init(type: optionsRawType.trimmed)])
            )
        }.as(DeclSyntax.self)
        
        // rawValue
        let rawValuePropertyDecl = VariableDeclSyntax(
            modifiers: .init([access].compactMap { $0 }),
            bindingSpecifier: .keyword(.var)
        ) {
            PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("rawValue")),
                    typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("RawValue"))),
                    accessorBlock: AccessorBlockSyntax(
                        accessors: .getter(CodeBlockItemListSyntax {
                            CodeBlockItemSyntax(
                                item: .expr(try! SwitchExprSyntax("switch self") {
                                    for enumCase in optionEnumCaseElements {
                                        SwitchCaseSyntax("case .\(enumCase.name.trimmed): return Options.\(enumCase.name.trimmed).rawValue")
                                    }
                                    
                                    SwitchCaseSyntax("case .other(let string): return string")
                                }.as(ExprSyntax.self)!)
                            )
                        })
                    )
                )
            }
        }.as(DeclSyntax.self)
        
        // init
        let initDecl = try! InitializerDeclSyntax("\(access)init(rawValue: RawValue)") {
            try! IfExprSyntax("if let this = Options(rawValue: rawValue)") {
                try! SwitchExprSyntax("switch this") {
                    for enumCase in optionEnumCaseElements {
                        SwitchCaseSyntax("case .\(enumCase.name.trimmed): self = .\(enumCase.name.trimmed)")
                    }
                }
            } else: {
                "self = .other(rawValue)"
            }
        }.as(DeclSyntax.self)
        
        return [
            allCases,
            rawValueTypeAliasDecl,
            casesDecl,
            rawValuePropertyDecl,
            initDecl
        ].compactMap { $0 }
    }
}

// MARK: - ExtensionMacro

extension OrOtherMacro: ExtensionMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard !protocols.isEmpty else { return [] }
        let extensionDeclStr = protocols
            .map(\.trimmedDescription)
            .joined(separator: ", ")
        
        let extensionDecl: DeclSyntax = "extension \(type.trimmed): \(raw: extensionDeclStr) {}"
        return [extensionDecl
            .cast(ExtensionDeclSyntax.self)]
    }
}

@main
struct OrOtherPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OrOtherMacro.self,
    ]
}
