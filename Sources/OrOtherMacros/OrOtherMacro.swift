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

        // typealias
        let rawValueTypeAliasDecl: DeclSyntax = "\(access)typealias RawValue = \(optionsRawType)"
        
        // cases
        let casesDecl = EnumCaseDeclSyntax {
            for enumCase in optionEnumCaseElements {
                EnumCaseElementSyntax(name: enumCase.name)
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
                                        SwitchCaseSyntax("case .\(enumCase.name): return Options.\(enumCase.name).rawValue")
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
                        SwitchCaseSyntax("case .\(enumCase.name): self = .\(enumCase.name)")
                    }
                }
            } else: {
                "self = .other(rawValue)"
            }
        }.as(DeclSyntax.self)
        
        return [
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
        var extensions = [DeclSyntax]()
        
        // MARK: RawRepresentable
        if !protocols.contains(where: { $0.as(InheritedTypeSyntax.self)?.type == "RawRepresentable" }) {
            extensions.append("extension \(type.trimmed): RawRepresentable {}")
        }
        
        return extensions.map { $0.cast(ExtensionDeclSyntax.self) }
    }
}

@main
struct OrOtherPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OrOtherMacro.self,
    ]
}
