//
//  RedPackage.swift
//  ARKitProject
//
//  Created by Zhou, James on 2024/11/15.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

class RedPackage: VirtualObject {
    override init() {
        super.init(modelName: "vase", fileExtension: "scn", thumbImageFilename: "vase", title: "Vase")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
