//
//  StatableTests.swift
//  StatableTests
//
//  Created by Denis Koryttsev on 21/11/16.
//  Copyright © 2016 Denis Koryttsev. All rights reserved.
//

import XCTest
@testable import Statable

struct PrinterState: Predicate, StateApplier {
    typealias EvaluatedObject = StatablePrinter
    typealias ApplyObject = StatablePrinter
    
    let value: () -> String
    let predicate: (_: StatablePrinter) -> Bool
    
    func evaluate(with entity: StatablePrinter) -> Bool {
        return predicate(entity)
    }
    
    func apply(for target: StatablePrinter) {
        target.printFunction = value
    }
}

class StatablePrinter: Statable {
    typealias StateUnit = PrinterState
    typealias StateType = PrinterState
    
    var boolState: Bool = false { didSet { applyCurrentState() } }
    var printFunction: (() -> String)? = nil
    var factors = [PrinterState]()
    var defaultState = PrinterState(value: { return "default state" }, predicate: { object in object.boolState == false && object.printFunction == nil })
    var state: PrinterState {
        return factors.first { $0.evaluate(with: self) } ?? defaultState
    }
    
    func apply(state: PrinterState) {
        state.apply(for: self)
    }
    
}

struct ObjectModePart: StateApplier {
    typealias ApplyObject = ModdableObject
    
    let applyFunction: (ModdableObject) -> ()
    var mode: ObjectMode? = nil
    
    init(applyFunction function: @escaping (ModdableObject) -> ()) {
        applyFunction = function
    }
    
    func apply(for target: ModdableObject) {
        applyFunction(target)
    }
    
    func applyIfNeeded(_ object: ModdableObject) {
        guard let owner = mode else { return }
        
        if owner.evaluate(with: object) {
            apply(for: object)
        }
    }
}

typealias ModeIdentifier = Int

class ObjectMode: Predicate, StateApplier {
    typealias EvaluatedObject = ModdableObject
    typealias ApplyObject = ModdableObject
    
    let predicate: (_: ModdableObject) -> Bool
    private var modeParts = [ObjectModePart]()
    var identifier: ModeIdentifier

    init(identifier id: Int, evaluateFunction function: @escaping (_: ModdableObject) -> Bool) {
        predicate = function
        identifier = id
    }
    
    func evaluate(with entity: ModdableObject) -> Bool {
        return predicate(entity)
    }
    
    func apply(for target: ModdableObject) {
        for part in modeParts {
            part.apply(for: target)
        }
    }
    
    func applyIfNeeded(for target: ModdableObject) {
        if evaluate(with: target) {
            apply(for: target)
        }
    }
    
    func add(_ part: inout ObjectModePart) {
        part.mode = self
        modeParts.append(part)
    }
}

class ModdableObject: Statable {
    typealias StateType = Int
    typealias StateUnit = ObjectMode
    
    var state: ModeIdentifier = 0 { didSet { applyCurrentState() } }
    internal var factors = [ObjectMode]()
    
    // moddable properties
    internal var commands = [String]()
    internal var modeName: String?
    
    func apply(state: ModeIdentifier) {
        factors.first { $0.evaluate(with: self) }?.apply(for: self)
    }
    
    func register(mode: ObjectMode) {
        factors.append(mode)
    }
    
    func add(part: ObjectModePart, for mode: ModeIdentifier) {
        var mutablePart = part
        factors.first { $0.identifier == mode }?.add(&mutablePart)
        mutablePart.applyIfNeeded(self)
    }
}

class StatableTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testStatablePrinter() {
        let statable = StatablePrinter()
        statable.applyCurrentState()
        
        XCTAssertTrue(statable.printFunction?() == "default state")
        
        statable.factors.append(PrinterState(value: { return "bool is true" }, predicate: { $0.boolState == true }))
        statable.factors.append(PrinterState(value: { return "bool is false" }, predicate: { $0.boolState == false }))
        
        statable.boolState = true
        XCTAssertTrue(statable.printFunction?() == "bool is true")
        statable.boolState = false
        XCTAssertTrue(statable.printFunction?() == "bool is false")
    }
    
    func testModdableObject() {
        let CollectionManager: ModeIdentifier = 0
        let DataManager: ModeIdentifier = 1
        let moddable = ModdableObject()
        
        moddable.register(mode: ObjectMode(identifier: CollectionManager, evaluateFunction: { $0.state == CollectionManager }))
        moddable.register(mode: ObjectMode(identifier: DataManager, evaluateFunction: { $0.state == DataManager }))
        
        moddable.applyCurrentState()
        XCTAssertTrue(moddable.commands.count == 0)
        
        moddable.add(part: ObjectModePart(applyFunction: { $0.commands = ["add", "remove"] } ), for: CollectionManager)
        XCTAssertTrue(moddable.commands == ["add", "remove"])
        
        moddable.add(part: ObjectModePart(applyFunction: { $0.commands = ["write", "read"] }), for: DataManager)
        XCTAssertTrue(moddable.commands == ["add", "remove"])
        
        moddable.add(part: ObjectModePart(applyFunction: { $0.modeName = "CollectionManager" }), for: CollectionManager)
        moddable.add(part: ObjectModePart(applyFunction: { $0.modeName = "DataManager" }), for: DataManager)
        moddable.state = DataManager
        XCTAssertTrue(moddable.commands == ["write", "read"])
        XCTAssertTrue(moddable.modeName == "DataManager")
        
        moddable.state = CollectionManager
        XCTAssertTrue(moddable.modeName == "CollectionManager")
        XCTAssertTrue(moddable.commands == ["add", "remove"])
    }
    
}
