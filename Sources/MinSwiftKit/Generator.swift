import Foundation
import LLVM

@discardableResult
func generateIRValue(from node: Node, with context: BuildContext) -> IRValue {
    switch node {
    case let numberNode as NumberNode:
        return Generator<NumberNode>(node: numberNode).generate(with: context)
    case let binaryExpressionNode as BinaryExpressionNode:
        return Generator<BinaryExpressionNode>(node: binaryExpressionNode).generate(with: context)
    case let variableNode as VariableNode:
        return Generator<VariableNode>(node: variableNode).generate(with: context)
    case let functionNode as FunctionNode:
        return Generator<FunctionNode>(node: functionNode).generate(with: context)
    case let callExpressionNode as CallExpressionNode:
        return Generator<CallExpressionNode>(node: callExpressionNode).generate(with: context)
    case let ifElseNode as IfElseNode:
        return Generator<IfElseNode>(node: ifElseNode).generate(with: context)
    case let returnNode as ReturnNode:
        return Generator<ReturnNode>(node: returnNode).generate(with: context)
    default:
        fatalError("Unknown node type \(type(of: node))")
    }
}

private protocol GeneratorProtocol {
    associatedtype NodeType: Node
    var node: NodeType { get }
    func generate(with: BuildContext) -> IRValue
    init(node: NodeType)
}

private struct Generator<NodeType: Node>: GeneratorProtocol {
    func generate(with context: BuildContext) -> IRValue {
        fatalError("Not implemented")
    }
    
    let node: NodeType
    init(node: NodeType) {
        self.node = node
    }
}

// MARK: Practice 6

extension Generator where NodeType == NumberNode {
    func generate(with context: BuildContext) -> IRValue {
        return FloatType.double.constant(node.value)
    }
}

extension Generator where NodeType == VariableNode {
    func generate(with context: BuildContext) -> IRValue {
        guard let variable = context.namedValues[node.identifier] else {
            fatalError("Undefined variable named \(node.identifier)")
        }
        return variable
    }
}

extension Generator where NodeType == BinaryExpressionNode {
    func generate(with context: BuildContext) -> IRValue {
        switch node.operator {
        case .addition:
            return context.builder.buildAdd(generateIRValue(from: node.lhs, with: context),
                                            generateIRValue(from: node.rhs, with: context),
                                            name: "addtmp")
        case .subtraction:
            return context.builder.buildSub(generateIRValue(from: node.lhs, with: context),
                                            generateIRValue(from: node.rhs, with: context),
                                            name: "subtmp")
        case .multication:
            return context.builder.buildMul(generateIRValue(from: node.lhs, with: context),
                                            generateIRValue(from: node.rhs, with: context),
                                            name: "multmp")
        case .division:
            return context.builder.buildDiv(generateIRValue(from: node.lhs, with: context),
                                            generateIRValue(from: node.rhs, with: context),
                                            name: "divtmp")
        case .lessThan:
            
            
            let bool = context.builder.buildFCmp(generateIRValue(from: node.lhs, with: context),
                                                 generateIRValue(from: node.rhs, with: context),
                                                 RealPredicate.orderedLessThan,
                                                 name: "cmptmp")
            return context.builder.buildIntToFP(bool, type: FloatType.double, signed: true)
        }
        
    }
}

extension Generator where NodeType == FunctionNode {
    func generate(with context: BuildContext) -> IRValue {
        let argumentTypes = [IRType](repeating: FloatType.double, count: node.arguments.count)
        let returnType: IRType = FloatType.double
        let functionType = FunctionType(argTypes: argumentTypes,
                                        returnType: returnType)
        let function = context.builder.addFunction(node.name, type: functionType)
        
        let entryBasicBlock = function.appendBasicBlock(named: "entry")
        context.builder.positionAtEnd(of: entryBasicBlock)
        
        context.namedValues.removeAll()
        for i in (0 ..< node.arguments.count) {
            context.namedValues[node.arguments[i].variableName] = function.parameters[i]
        }
    
        let functionBody: IRValue = generateIRValue(from: node.body, with: context)
        context.builder.buildRet(functionBody)
        return functionBody
    }
}

extension Generator where NodeType == CallExpressionNode {
    func generate(with context: BuildContext) -> IRValue {
        guard let function = context.builder.module.function(named: node.callee) else {
            fatalError("can not get function")
        }
        var arguments: [IRValue] = []
        node.arguments.forEach { (argument) in
            let value: IRValue = generateIRValue(from: argument.value, with: context)
            arguments.append(value)
        }
        return context.builder.buildCall(function, args: arguments, name: "calltmp")
    }
}

extension Generator where NodeType == IfElseNode {
    func generate(with context: BuildContext) -> IRValue {
        let condition: IRValue = generateIRValue(from: node.condition, with: context)
        
        let boolean = context.builder.buildFCmp(condition,
                                                FloatType.double.constant(0.0),
                                                RealPredicate.orderedNotEqual,
                                                name: "ifcond")
        
        guard let function = context.builder.insertBlock?.parent! else {
            fatalError("function is nil")
        }
        
        let local = context.builder.buildAlloca(type: FloatType.double, name: "local")
        
        let thenBasicBlock = function.appendBasicBlock(named: "then")
        let elseBasicBlock = function.appendBasicBlock(named: "else")
        let mergeBasicBlock = function.appendBasicBlock(named: "merge")
        
        context.builder.buildCondBr(condition: boolean, then: thenBasicBlock, else: elseBasicBlock)
        context.builder.positionAtEnd(of: thenBasicBlock)
        
        let thenVal: IRValue = generateIRValue(from: node.then, with: context)
        context.builder.buildBr(mergeBasicBlock)
        
        context.builder.positionAtEnd(of: elseBasicBlock)
        
        let elseVal: IRValue = generateIRValue(from: node.else!, with: context)
        context.builder.buildBr(mergeBasicBlock)
        
        context.builder.positionAtEnd(of: mergeBasicBlock)
        
        let phi = context.builder.buildPhi(FloatType.double, name: "phi")
        phi.addIncoming([(thenVal, thenBasicBlock), (elseVal, elseBasicBlock)])
        context.builder.buildStore(phi, to: local)
        
        return phi
    }
}

extension Generator where NodeType == ReturnNode {
    func generate(with context: BuildContext) -> IRValue {
        if let body = node.body {
            let returnValue = MinSwiftKit.generateIRValue(from: body, with: context)
            return returnValue
        } else {
            return VoidType().null()
        }
    }
}
