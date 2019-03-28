import Foundation
import XCTest
@testable import MinSwiftKit

final class Practice8: XCTestCase {
    private let engine = Engine()

    // Don't worry, you already have everything 😈

    // 8-1
    func testCube() {
        let source = """
        func cube(a: Double) -> Double {
            return a * a * a
        }
        """
        try! engine.load(from: source)
        typealias FunctionType = @convention(c) (Double) -> Double
        try! engine.run("cube", of: FunctionType.self) { cube in
            XCTAssertEqual(cube(3), 27)
            XCTAssertEqual(cube(42), 74088)
        }
    }

    // 8-2
    func testFactorial() {
        let source = """
        func factorial(a: Double) -> Double {
            if 1 < a {
                return a * factorial(a: a - 1)
            } else {
                return 1
            }
        }
        """
        try! engine.load(from: source)
        typealias FunctionType = @convention(c) (Double) -> Double
        try! engine.run("factorial", of: FunctionType.self) { factorial in
            XCTAssertEqual(factorial(4), 24)
            XCTAssertEqual(factorial(6), 720)
            XCTAssertEqual(factorial(10), 3628800)
        }
    }

    // 8-3
    func testFibonacci() {
        let source = """
func fibonacci(_ x: Double) -> Double {
    if x < 3 {
        return 1
    } else {
        return fibonacci(x - 1) + fibonacci(x - 2)
    }
}
"""
        try! engine.load(from: source)
        typealias FunctionType = @convention(c) (Double) -> Double
        try! engine.run("fibonacci", of: FunctionType.self) { fib in
            XCTAssertEqual(fib(10), 55)
            XCTAssertEqual(fib(20), 6765)
        }
    }
}
