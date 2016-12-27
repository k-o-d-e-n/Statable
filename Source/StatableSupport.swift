//
//  StatableSupport.swift
//  Statable
//
//  Created by Denis Koryttsev on 03/12/16.
//  Copyright © 2016 Denis Koryttsev. All rights reserved.
//

import Foundation

// issue: does not conform Predicate protocol, this is expirement
open class QNSPredicate<Evaluated: AnonymStatable>: NSPredicate {
    typealias EvaluatedEntity = Evaluated
}

extension NSPredicate: Predicate {
    public typealias EvaluatedEntity = Any?
}

open class BlockPredicate<Evaluated>: Predicate {
    public typealias EvaluatedEntity = Evaluated
    
    internal let predicate: (_ object: Evaluated) -> Bool
    
    public init(predicate: @escaping (_ object: Evaluated) -> Bool) {
        self.predicate = predicate
    }
    
    public func evaluate(with object: Evaluated) -> Bool {
        return predicate(object)
    }
}
