//
//  RedPackageNode.swift
//  ARKitProject
//
//  Created by Zhou, James on 2024/11/18.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import SceneKit

class RedPackageNode: NSObject {
    static let redPackageImage = "red-package"
    static let redPackageName = "red-package-node"
    
    static func loadRedPackage() -> SCNNode {
        let geometry = SCNBox(width: 1.0, height: 1.0, length: 0.01, chamferRadius: 0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: RedPackageNode.redPackageImage)
        geometry.materials = [material, material, material, material, material, material]

        let geometryNode = SCNNode(geometry: geometry)
        geometryNode.name = RedPackageNode.redPackageName
        geometryNode.light = SCNLight()
        geometryNode.light?.type = .omni
        geometryNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)

        let x = Int(arc4random_uniform(9)) - 4
        let y = 1
        let z = Int(arc4random_uniform(9)) - 4
        let force = SCNVector3(x: Float(x), y: -Float(y), z: Float(z))
        let positionForce = SCNVector3(x: 0.05, y: 0.05, z: 0.05)
        geometryNode.physicsBody?.applyForce(force, at: positionForce, asImpulse: true)
        return geometryNode
    }
}
