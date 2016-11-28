//
//  ViewController.swift
//  Statable
//
//  Created by Denis Koryttsev on 21/11/16.
//  Copyright © 2016 Denis Koryttsev. All rights reserved.
//

import UIKit

enum TrafficLightElementTransitionBehavior {
    case light
    case blink
    
    func runFor(element: TrafficLightElementView, color: UIColor) {
        switch self {
        case .light:
            element.backgroundColor = color
        case .blink:
            element.backgroundColor = nil
            let blinkAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.backgroundColor))
            blinkAnimation.repeatCount = .infinity
            blinkAnimation.fromValue = nil
            blinkAnimation.toValue = color.cgColor
            blinkAnimation.duration = 0.4
            element.layer.add(blinkAnimation, forKey: "background.blink")
        }
    }
}

enum TrafficLightElement {
    case red, yellow, green
    
    var color: UIColor {
        switch self {
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        }
    }

}

enum TrafficLightElementState: StatePredicate {
    case enabled
    case disabled
    case transition
    
    typealias EvaluatedObject = TrafficLightElementView
    
    func evaluate(_ object: TrafficLightElementView) -> Bool {
        return self == object.state
    }
    
}

class TrafficLightElementView: UIView, Statable, StateApplier {
    typealias ApplyObject = TrafficLightElementView
    typealias StateType = TrafficLightElementState
    typealias StatePredicate = TrafficLightElementState
    
    var state: TrafficLightElementState = .disabled { didSet { applyCurrentState() } }
    var stateUnits: [TrafficLightElementState] = [.enabled, .disabled, .transition]
    let element: TrafficLightElement
    let transitionBehavior: TrafficLightElementTransitionBehavior
    
    required init(frame: CGRect, element: TrafficLightElement, transition: TrafficLightElementTransitionBehavior) {
        self.element = element
        self.transitionBehavior = transition
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func apply(_ state: TrafficLightElementState) {
        apply(self)
    }
    
    func apply(_ object: TrafficLightElementView) {
        object.layer.removeAllAnimations()
        switch object.state {
        case .enabled:
            object.backgroundColor = element.color
        case .transition:
            transitionBehavior.runFor(element: object, color: element.color)
        case .disabled:
            object.backgroundColor = nil
        }
    }
}

enum TrafficLightState {
    case green
    case blinkingGreen
    case yellow
    case yellowRed
    case red
    
    var next: TrafficLightState {
        switch self {
        case .green: return .blinkingGreen
        case .blinkingGreen: return .yellow
        case .yellow: return .red
        case .yellowRed: return .green
        case .red: return .yellowRed
        }
    }
    
    func stateFor(element: TrafficLightElement) -> TrafficLightElementState {
        switch self {
        case .green:
            return element == .green ? .enabled : .disabled
        case .blinkingGreen:
            return element == .green ? .transition : .disabled
        case .yellow:
            return element == .yellow ? .enabled : .disabled
        case .yellowRed:
            return element == .red || element == .yellow ? .transition : .disabled
        case .red:
            return element == .red ? .enabled : .disabled
        }
    }
    
}

struct TrafficLightStatePredicate: StatePredicate, StateApplier {
    typealias EvaluatedObject = TrafficLightView
    typealias ApplyObject = TrafficLightView
    let state: TrafficLightState
    let applyTime: TimeInterval
    
    func evaluate(_ object: TrafficLightView) -> Bool {
        return state == object.state
    }
    
    func apply(_ object: TrafficLightView) {
        object.greenElement.state = state.stateFor(element: object.greenElement.element)
        object.yellowElement.state = state.stateFor(element: object.yellowElement.element)
        object.redElement.state = state.stateFor(element: object.redElement.element)
        DispatchQueue.main.asyncAfter(deadline: .now() + applyTime) {
            object.applyNext()
        }
    }
    
}

class TrafficLightView: UIView, Statable {
    typealias StateType = TrafficLightState
    typealias StatePredicate = TrafficLightStatePredicate
    
    var stateUnits = [TrafficLightStatePredicate]()
    var state: TrafficLightState = .green
    weak var greenElement: TrafficLightElementView!
    weak var yellowElement: TrafficLightElementView!
    weak var redElement: TrafficLightElementView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.borderWidth = 2
        
        stateUnits.append(TrafficLightStatePredicate(state: .green, applyTime: 5))
        stateUnits.append(TrafficLightStatePredicate(state: .blinkingGreen, applyTime: 3))
        stateUnits.append(TrafficLightStatePredicate(state: .yellow, applyTime: 2))
        stateUnits.append(TrafficLightStatePredicate(state: .yellowRed, applyTime: 2))
        stateUnits.append(TrafficLightStatePredicate(state: .red, applyTime: 5))
        
        setupElements()
    }
    
    private func setupElements() {
        let green = TrafficLightElementView(frame: .zero, element: .green, transition: .blink)
        let yellow = TrafficLightElementView(frame: .zero, element: .yellow, transition: .light)
        let red = TrafficLightElementView(frame: .zero, element: .red, transition: .light)
        self.addSubview(green); greenElement = green
        self.addSubview(yellow); yellowElement = yellow
        self.addSubview(red); redElement = red
    }
    
    override func layoutSubviews() {
        let heightWidth = (self.frame.height / 3) - 2
        redElement.frame = CGRect(x: 2, y: 2, width: heightWidth, height: heightWidth)
        yellowElement.frame = CGRect(x: 2, y: heightWidth + 2, width: heightWidth, height: heightWidth)
        greenElement.frame = CGRect(x: 2, y: (heightWidth * 2) + 2, width: heightWidth, height: heightWidth)
        redElement.layer.cornerRadius = heightWidth / 2
        yellowElement.layer.cornerRadius = heightWidth / 2
        greenElement.layer.cornerRadius = heightWidth / 2
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func applyNext() {
        self.state = state.next
        applyCurrentState()
    }
    
    func apply(_ state: TrafficLightState) {
        stateUnits.first { $0.evaluate(self) }?.apply(self)
    }
    
    func run() {
        applyCurrentState()
    }
    
}

class ViewController: UIViewController {
    weak var trafficLight: TrafficLightView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let light = TrafficLightView(frame: CGRect(x: view.frame.midX - 52, y: 100, width: 104, height: 306))
        view.addSubview(light)
        trafficLight = light
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trafficLight.run()
    }

}

