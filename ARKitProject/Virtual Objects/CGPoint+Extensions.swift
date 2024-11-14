//
//  CGPoint+Extensions.swift
//  ARKitProject
//
//  Created by Tao, Wang on 2024/11/12.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(self.x - point.x, 2) + pow(self.y - point.y, 2))
    }
}
