//
//  ViewController.swift
//  Statable
//
//  Created by Denis Koryttsev on 21/11/16.
//  Copyright © 2016 Denis Koryttsev. All rights reserved.
//

import UIKit
import Statable

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

enum TrafficLightElementState: Predicate {
    case enabled
    case disabled
    case transition
    
    typealias EvaluatedObject = TrafficLightElementView
    
    func evaluate(with entity: TrafficLightElementView) -> Bool {
        return self == entity.state
    }
    
}

class TrafficLightElementView: UIView, Statable, StateApplier {
    typealias ApplyObject = TrafficLightElementView
    typealias StateType = TrafficLightElementState
    typealias StatePredicate = TrafficLightElementState
    
    var state: TrafficLightElementState = .disabled { didSet { applyCurrentState() } }
    var factors: [TrafficLightElementState] = [.enabled, .disabled, .transition]
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
    
    func apply(state: TrafficLightElementState) {
        apply(for: self)
    }
    
    func apply(for object: TrafficLightElementView) {
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
    
    var automobileState: AutomobileState {
        switch self {
        case .green: return .drive
        case .blinkingGreen: return .drive
        case .yellow: return .stopped
        case .yellowRed: return .stopped
        case .red: return .stopped
        }
    }
    
}

struct TrafficLightStatePredicate: Predicate, StateApplier {
    typealias EvaluatedObject = TrafficLightView
    typealias ApplyObject = TrafficLightView
    let state: TrafficLightState
    let applyTime: TimeInterval
    
    func evaluate(with object: TrafficLightView) -> Bool {
        return state == object.state
    }
    
    func apply(for object: TrafficLightView) {
        object.greenElement.state = state.stateFor(element: object.greenElement.element)
        object.yellowElement.state = state.stateFor(element: object.yellowElement.element)
        object.redElement.state = state.stateFor(element: object.redElement.element)
        DispatchQueue.main.asyncAfter(deadline: .now() + applyTime) {
            object.applyNext()
        }
    }
    
}

enum AutomobileState: Predicate, StateApplier {
    typealias EvaluatedEntity = Automobile
    typealias ApplyTarget = Automobile
    
    case drive
    case stopped
    
    func evaluate(with entity: Automobile) -> Bool {
        return self == entity.state
    }
    
    func apply(for target: Automobile) {
        switch target.state {
        case .drive:
            target.view.frame.origin.y += 2
        case .stopped:
            break
        }
    }
}

class Automobile: StateSubscriber, Hashable, Statable {
    typealias StateType = AutomobileState
    typealias Factor = AutomobileState
    typealias EvaluatedEntity = TrafficLightState
    
    var factors: [AutomobileState] = [.drive, .stopped]
    var state: AutomobileState = .stopped
    
    let name: String
    weak var trafficLight: TrafficLightView?
    weak var view: AutomobileView!
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    init(name: String) {
        self.name = name
    }
    
    func invoke() {
        switch trafficLight!.state.automobileState {
        case .drive:
            print("\(name) drove")
            view.frame.origin.y += 5
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                self.invoke()
            }
        default:
            print("\(name) stopped")
        }
    }
    
    func apply(state: AutomobileState) {
        state.apply(for: self)
    }
    
    /// evaluate for notify (call invoke() function)
    func evaluate(with entity: TrafficLightState) -> Bool {
        return entity.automobileState != state
    }
    
    static func ==(lhs: Automobile, rhs: Automobile) -> Bool {
        return lhs.name == rhs.name
    }
}

class TrafficLightView: UIView, Statable {
    typealias StateType = TrafficLightState
    typealias StatePredicate = TrafficLightStatePredicate
    
    var factors = [TrafficLightStatePredicate]()
    var state: TrafficLightState = .green {
        didSet {
            for waitedAuto in trafficJam {
                waitedAuto.invoke(ifMatched: state)
            }
        }
    }
    weak var greenElement: TrafficLightElementView!
    weak var yellowElement: TrafficLightElementView!
    weak var redElement: TrafficLightElementView!
    
    var trafficJam = [Automobile]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderWidth = 2
        
        factors.append(TrafficLightStatePredicate(state: .green, applyTime: 5))
        factors.append(TrafficLightStatePredicate(state: .blinkingGreen, applyTime: 3))
        factors.append(TrafficLightStatePredicate(state: .yellow, applyTime: 2))
        factors.append(TrafficLightStatePredicate(state: .yellowRed, applyTime: 2))
        factors.append(TrafficLightStatePredicate(state: .red, applyTime: 5))
        
        setupElements()
    }
    
    private func setupElements() {
        let green = TrafficLightElementView(frame: .zero, element: .green, transition: .blink)
        let yellow = TrafficLightElementView(frame: .zero, element: .yellow, transition: .light)
        let red = TrafficLightElementView(frame: .zero, element: .red, transition: .light)
        addSubview(green); greenElement = green
        addSubview(yellow); yellowElement = yellow
        addSubview(red); redElement = red
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
        state = state.next
        applyCurrentState()
    }
    
    func apply(state: TrafficLightState) {
        factors.first { $0.evaluate(with: self) }?.apply(for: self)
    }
    
    func addWaiting(auto: Automobile) {
        auto.trafficLight = self
        trafficJam.append(auto)
    }
    
    func removeWaiting(auto: Automobile) {
        auto.trafficLight = nil
        if let index = trafficJam.firstIndex(where: { $0 == auto }) {
            trafficJam.remove(at: index)
        }
    }
    
    func run() {
        applyCurrentState()
    }
}

extension TrafficLightView: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            layer.frame = layer.presentation()!.frame.integral
            layer.removeAnimation(forKey: "animation")
        }
    }
}

class ViewController: UIViewController {
    weak var trafficLight: TrafficLightView!
    let velocity: TimeInterval = 0.4
    static let automobiles = ["Plymouth Hemicuda 1970", "Plymouth Hemicuda 1971", "Plymouth Hemicuda 1972", "Plymouth Hemicuda 1973", "Plymouth Hemicuda 1974", "Plymouth Hemicuda 1975"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let light = TrafficLightView(frame: CGRect(x: view.frame.midX - 52, y: 100, width: 104, height: 306))
        view.addSubview(light)
        trafficLight = light
        let automobiles = ViewController.automobiles.map { Automobile(name: $0) }
        automobiles.forEach {
            let view = AutomobileView(auto: $0)
            view.frame = CGRect(origin: CGPoint(x: 0, y: 0 - (trafficLight.trafficJam.count * 21)), size: CGSize(width: 150, height: 20))
            self.view.addSubview(view)
            $0.view = view
            trafficLight.addWaiting(auto: $0)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trafficLight.run()
    }

}

class AutomobileView: UIView {
    private weak var titleLabel: UILabel!
    var auto: Automobile! {
        didSet { titleLabel.text = auto.name }
    }
        
    convenience init(auto: Automobile) {
        self.init(frame: .zero)
        self.auto = auto
        titleLabel.text = auto.name
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderWidth = 1
        loadTitleLabel()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds
    }
    
    func loadTitleLabel() {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 10)
        label.textAlignment = .center
        addSubview(label)
        self.titleLabel = label
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

