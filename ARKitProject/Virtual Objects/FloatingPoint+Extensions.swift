//
//  FloatingPoint+Extensions.swift
//  ARKitProject
//
//  Created by Tao, Wang on 2024/11/12.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}
