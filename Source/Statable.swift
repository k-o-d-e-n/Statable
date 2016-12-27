//
//  Statable.swift
//  Statable
//
//  Created by Denis Koryttsev on 21/11/16.
//  Copyright © 2016 Denis Koryttsev. All rights reserved.
//

import Foundation

// MARK: Statable

public protocol AnonymStatable {
    associatedtype StateType
    associatedtype Factor: Predicate
    
    var factors: [Factor] { get }
    
    func apply(state: StateType)
}

public protocol Statable: AnonymStatable {
    var state: StateType { get }
}

public extension Statable {
    func applyCurrentState() {
        apply(state: state)
    }
}

/*!
     override func applyCurrentState() {
        let currentState = state
        if (oldState == currentState) return
     
        super.applyCurrentState()
     }
 */
public protocol KnownStatable: Statable {
    var lastAppliedState: StateType { get }
}

// MARK: Predicates

public protocol Predicate {
    associatedtype EvaluatedEntity
    
    func evaluate(with entity: EvaluatedEntity) -> Bool
}

public protocol StateFactor: Predicate {
    associatedtype StateType
    
    func mark(state: inout StateType)
}

public extension StateFactor {
    func mark(state: inout StateType, ifEvaluatedWith entity: EvaluatedEntity) {
        if evaluate(with: entity) {
            mark(state: &state)
        }
    }
}

public protocol StateDescriptor: Predicate {
    var state: EvaluatedEntity { get }
    
    func evaluate(with entity: EvaluatedEntity) -> Bool
}

// MARK: State Appliers

public protocol StateApplier {
    associatedtype ApplyTarget
    
    func apply(for target: ApplyTarget)
}

public protocol StatesApplier {
    associatedtype StateType
    associatedtype ApplyTarget
    
    func apply(state: StateType, for target: ApplyTarget)
}

// MARK: Subscribers

public protocol StateSubscriber: Predicate {
    func invoke()
}

public extension StateSubscriber {
    func invoke(ifMatched entity: EvaluatedEntity) {
        if evaluate(with: entity) {
            invoke()
        }
    }
}
