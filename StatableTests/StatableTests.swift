//
//  StatableTests.swift
//  StatableTests
//
//  Created by Denis Koryttsev on 21/11/16.
//  Copyright © 2016 Denis Koryttsev. All rights reserved.
//

import XCTest
@testable import Statable

struct PrinterState: StateUnit, StateApplier {
    typealias EvaluatedObject = StatablePrinter
    typealias ApplyObject = StatablePrinter
    let value: () -> String
    let evaluateFunction: (_: StatablePrinter) -> Bool
    
    func evaluate(_ object: StatablePrinter) -> Bool {
        return evaluateFunction(object)
    }
    
    func apply(_ object: StatablePrinter) {
        object.printFunction = value
    }
}

class StatablePrinter: Statable {
    typealias StateUnit = PrinterState
    var boolState: Bool = false { didSet { applyCurrentState() } }
    var printFunction: (() -> String)? = nil
    var stateUnits = [PrinterState]()
    var defaultState = PrinterState(value: { return "default state" }, evaluateFunction: { object in object.boolState == false && object.printFunction == nil })
    var state: PrinterState {
        return stateUnits.first { $0.evaluate(self) } ?? defaultState
    }
    
    func apply(_ state: PrinterState) {
        state.apply(self)
    }
    
}

struct ObjectModePart: StateApplier {
    typealias ApplyObject = ModdableObject
    let applyFunction: (ModdableObject) -> ()
    var mode: ObjectMode? = nil
    
    init(applyFunction function: @escaping (ModdableObject) -> ()) {
        applyFunction = function
    }
    
    func apply(_ object: ModdableObject) {
        applyFunction(object)
    }
    
    func applyIfNeeded(_ object: ModdableObject) {
        guard let owner = mode else { return }
        
        if owner.evaluate(object) {
            apply(object)
        }
    }
}

typealias ModeIdentifier = Int

class ObjectMode: StateUnit, StateApplier {
    typealias EvaluatedObject = ModdableObject
    typealias ApplyObject = ModdableObject
    let evaluateFunction: (_: ModdableObject) -> Bool
    private var modeParts = [ObjectModePart]()
    var identifier: ModeIdentifier

    init(identifier id: Int, evaluateFunction function: @escaping (_: ModdableObject) -> Bool) {
        evaluateFunction = function
        identifier = id
    }
    
    func evaluate(_ object: ModdableObject) -> Bool {
        return evaluateFunction(object)
    }
    
    func apply(_ object: ModdableObject) {
        for part in modeParts {
            part.apply(object)
        }
    }
    
    func applyIfNeeded(_ object: ModdableObject) {
        if evaluate(object) {
            apply(object)
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
    internal var stateUnits = [ObjectMode]()
    
    // moddable properties
    internal var commands = [String]()
    internal var modeName: String?
    
    func apply(_ state: ModeIdentifier) {
        stateUnits.first { $0.evaluate(self) }?.apply(self)
    }
    
    func register(mode: ObjectMode) {
        stateUnits.append(mode)
    }
    
    func add(part: ObjectModePart, for mode: ModeIdentifier) {
        var mutablePart = part
        stateUnits.first { $0.identifier == mode }?.add(&mutablePart)
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
        
        statable.stateUnits.append(PrinterState(value: { return "bool is true" }, evaluateFunction: { $0.boolState == true }))
        statable.stateUnits.append(PrinterState(value: { return "bool is false" }, evaluateFunction: { $0.boolState == false }))
        
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
