import Foundation
import SwiftSyntax

class Parser: SyntaxVisitor {
    private(set) var tokens: [TokenSyntax] = []
    private var index = 0
    private(set) var currentToken: TokenSyntax!

    // MARK: Practice 1

    override func visit(_ token: TokenSyntax) {
        // print("Parsing \(token.tokenKind)")
        tokens.append(token)
    }

    @discardableResult
    func read() -> TokenSyntax {
        if tokens.count <= index {
            fatalError("index is out of range")
        }
        currentToken = tokens[index]
        index += 1
        return currentToken
    }

    func peek(_ n: Int = 0) -> TokenSyntax {
        if tokens.count <= index - 1 + n {
            fatalError("index is out of range")
        }
        return tokens[index - 1 + n]
    }

    // MARK: Practice 2

    private func extractNumberLiteral(from token: TokenSyntax) -> Double? {
        switch token.tokenKind {
        case .integerLiteral, .floatingLiteral:
            return Double(token.text)
        default:
            return nil
        }
    }

    func parseNumber() -> Node {
        guard let value = extractNumberLiteral(from: currentToken) else {
            fatalError("any number is expected")
        }
        read() // eat literal
        return NumberNode(value: value)
    }

    func parseIdentifierExpression() -> Node {
        guard let valueToken = currentToken,
            case .identifier = valueToken.tokenKind else {
            fatalError("currentTokenKind is expected identifier")
        }
        read()
        if currentToken.tokenKind == .leftParen {
            read()
            var arguments: [CallExpressionNode.Argument] = []
            while true  {
                if currentToken.tokenKind == .rightParen {
                    read()
                    break
                } else if currentToken.tokenKind == .comma {
                    read()
                }
                var label: String? = nil
                if peek(1).tokenKind == .colon {
                    guard let labelToken = currentToken, case .identifier = labelToken.tokenKind else {
                        fatalError("labelTokenKind is expected identifier")
                    }
                    label = labelToken.text
                    read()
                    read()
                }
                guard let node = parseExpression() else {
                    fatalError("node is expected not nil")
                }
                arguments.append(CallExpressionNode.Argument(label: label,
                                                             value: node))
            }
            return CallExpressionNode(callee: valueToken.text,
                                      arguments: arguments)
        } else {
            return VariableNode(identifier: valueToken.text)
        }
    }

    // MARK: Practice 3

    func extractBinaryOperator(from token: TokenSyntax) -> BinaryExpressionNode.Operator? {
        guard case .spacedBinaryOperator = token.tokenKind else {
            return nil
        }
        return BinaryExpressionNode.Operator(rawValue: token.text)
    }

    private func parseBinaryOperatorRHS(expressionPrecedence: Int, lhs: Node?) -> Node? {
        var currentLHS: Node? = lhs
        while true {
            let binaryOperator = extractBinaryOperator(from: currentToken!)
            let operatorPrecedence = binaryOperator?.precedence ?? -1
            
            // Compare between nextOperator's precedences and current one
            if operatorPrecedence < expressionPrecedence {
                return currentLHS
            }
            
            read() // eat binary operator
            var rhs = parsePrimary()
            if rhs == nil {
                return nil
            }
            
            // If binOperator binds less tightly with RHS than the operator after RHS, let
            // the pending operator take RHS as its LHS.
            let nextPrecedence = extractBinaryOperator(from: currentToken)?.precedence ?? -1
            if (operatorPrecedence < nextPrecedence) {
                // Search next RHS from currentRHS
                // next precedence will be `operatorPrecedence + 1`
                rhs = parseBinaryOperatorRHS(expressionPrecedence: operatorPrecedence + 1, lhs: rhs)
                if rhs == nil {
                    return nil
                }
            }
            
            guard let nonOptionalRHS = rhs else {
                fatalError("rhs must be nonnull")
            }
            
            currentLHS = BinaryExpressionNode(binaryOperator!,
                                              lhs: currentLHS!,
                                              rhs: nonOptionalRHS)
        }
    }

    // MARK: Practice 4

    func parseFunctionDefinitionArgument() -> FunctionNode.Argument {
        var label: String? = ""
        if currentToken.tokenKind == .wildcardKeyword {
            label = nil
            read()
        } else if case .identifier = peek(1).tokenKind {
            //Swift.print(currentToken.tokenKind)
            guard let labelToken = currentToken, case .identifier = labelToken.tokenKind else {
                fatalError("currentTokenKind is expected identifier")
            }
            label = labelToken.text
            read()
        }
        guard let nameToken = currentToken,
            case .identifier = nameToken.tokenKind else {
            fatalError("currentTokenKind is expected identifier")
        }
        if label != nil, label!.isEmpty {
            label = nameToken.text
        }
        read()
        guard currentToken.tokenKind == .colon else {
            fatalError("currentTokenKind is expected colon")
        }
        read()
        guard case .identifier = currentToken.tokenKind else {
            fatalError("currentTokenKind is expected identifier")
        }
        read()
        return FunctionNode.Argument(label: label, variableName: nameToken.text)
    }

    func parseFunctionDefinition() -> Node {
        guard currentToken.tokenKind == .funcKeyword else {
            fatalError("currentTokenKind is expected funcKeyword")
        }
        read()
        guard let nameToken = currentToken,
            case .identifier = nameToken.tokenKind else {
            fatalError("currentTokenKind is expected funcKeyword")
        }
        read()
        guard currentToken.tokenKind == .leftParen else {
            fatalError("currentTokenKind is expected leftParen")
        }
        read()
        var arguments: [FunctionNode.Argument] = []
        while true  {
            if currentToken.tokenKind == .rightParen {
                read()
                break
            } else if currentToken.tokenKind == .comma {
                read()
            }
            arguments.append(parseFunctionDefinitionArgument())
        }
        var type = Type.void
        if currentToken.tokenKind == .arrow {
            read()
            guard case .identifier = currentToken.tokenKind else {
                fatalError("currentTokenKind is expected identifier")
            }
            type = Type.double
            read()
        }
        guard currentToken.tokenKind == .leftBrace else {
            fatalError("currentTokenKind is expected leftBrace")
        }
        read()
        guard let body = parseExpression() else {
            fatalError("body is expected not nil")
        }
        guard currentToken.tokenKind == .rightBrace else {
            fatalError("currentTokenKind is expected rightBrace")
        }
        read()
        return FunctionNode(name: nameToken.text,
                            arguments: arguments,
                            returnType: type,
                            body: body)
    }

    // MARK: Practice 7

    func parseIfElse() -> Node {
        Swift.print(currentToken.tokenKind)
        guard currentToken.tokenKind == .ifKeyword else {
            fatalError("currentTokenKind is expected ifKeyword")
        }
        read()
        guard let conditionBody = parseExpression() else {
            fatalError("body is expected not nil")
        }
        guard currentToken.tokenKind == .leftBrace else {
            fatalError("currentTokenKind is expected leftBrace")
        }
        read()
        guard let ifBody = parseExpression() else {
            fatalError("body is expected not nil")
        }
        guard currentToken.tokenKind == .rightBrace else {
            fatalError("currentTokenKind is expected rightBrace")
        }
        read()
        guard currentToken.tokenKind == .elseKeyword else {
            fatalError("currentTokenKind is expected elseKeyword")
        }
        read()
        
        guard currentToken.tokenKind == .leftBrace else {
            fatalError("currentTokenKind is expected leftBrace")
        }
        read()
        guard let elseBody = parseExpression() else {
            fatalError("body is expected not nil")
        }
        guard currentToken.tokenKind == .rightBrace else {
            fatalError("currentTokenKind is expected rightBrace")
        }
        read()
        return IfElseNode(condition: conditionBody, then: ifBody, else: elseBody)
    }

    // PROBABLY WORKS WELL, TRUST ME

    func parse() -> [Node] {
        var nodes: [Node] = []
        read()
        while true {
            switch currentToken.tokenKind {
            case .eof:
                return nodes
            case .funcKeyword:
                let node = parseFunctionDefinition()
                nodes.append(node)
            default:
                if let node = parseTopLevelExpression() {
                    nodes.append(node)
                    break
                } else {
                    read()
                }
            }
        }
        return nodes
    }

    private func parsePrimary() -> Node? {
        switch currentToken.tokenKind {
        case .identifier:
            return parseIdentifierExpression()
        case .integerLiteral, .floatingLiteral:
            return parseNumber()
        case .leftParen:
            return parseParen()
        case .funcKeyword:
            return parseFunctionDefinition()
        case .returnKeyword:
            return parseReturn()
        case .ifKeyword:
            return parseIfElse()
        case .eof:
            return nil
        default:
            fatalError("Unexpected token \(currentToken.tokenKind) \(currentToken.text)")
        }
        return nil
    }

    func parseExpression() -> Node? {
        guard let lhs = parsePrimary() else {
            return nil
        }
        return parseBinaryOperatorRHS(expressionPrecedence: 0, lhs: lhs)
    }

    private func parseReturn() -> Node {
        guard case .returnKeyword = currentToken.tokenKind else {
            fatalError("returnKeyword is expected but received \(currentToken.tokenKind)")
        }
        read() // eat return
        if let expression = parseExpression() {
            return ReturnNode(body: expression)
        } else {
            // return nothing
            return ReturnNode(body: nil)
        }
    }

    private func parseParen() -> Node? {
        read() // eat (
        guard let v = parseExpression() else {
            return nil
        }

        guard case .rightParen = currentToken.tokenKind else {
                fatalError("expected ')'")
        }
        read() // eat )

        return v
    }

    private func parseTopLevelExpression() -> Node? {
        if let expression = parseExpression() {
            // we treat top level expressions as anonymous functions
            let anonymousPrototype = FunctionNode(name: "main", arguments: [], returnType: .int, body: expression)
            return anonymousPrototype
        }
        return nil
    }
}

private extension BinaryExpressionNode.Operator {
    var precedence: Int {
        switch self {
        case .addition, .subtraction: return 20
        case .multication, .division: return 40
        case .lessThan: return 10
        }
    }
}
