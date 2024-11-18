//
//  CountDownTimer.swift
//  ARKitProject
//
//  Created by Zhou, James on 2024/11/17.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

class CountdownTimer {
    
    private var timer: Timer?
    private var countdownTime: Int
    private var initialTime: Int
    private var timeUpHandler: (() -> Void)?
    private var tickHandler: ((Int) -> Void)?
    
    init(startTime: Int = 60, timeUpHandler: @escaping (() -> Void), tickHandler: @escaping ((Int) -> Void)) {
        self.countdownTime = startTime
        self.initialTime = startTime
        self.timeUpHandler = timeUpHandler
        self.tickHandler = tickHandler
    }
    
    func start() {
        stop()
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        stop()
        countdownTime = initialTime
        start()
    }
    
    func getCurrentTime() -> Int {
        return countdownTime
    }
    
    @objc private func tick() {
        countdownTime -= 1
        tickHandler?(countdownTime)
        if countdownTime <= 0 {
            stop()
            timeUpHandler?()
        }
    }
}
