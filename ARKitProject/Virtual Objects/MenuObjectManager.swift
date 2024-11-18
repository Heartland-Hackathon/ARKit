//
//  MenuObjectManager.swift
//  ARKitProject
//
//  Created by Zhou, James on 2024/11/18.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

struct MenuItem: Codable {
    var itemId: Int = 0
    var itemName: String = ""
}

class MenuObjectManager {
    
    static let share = MenuObjectManager()
    
    var menuVirtualObjects: [VirtualObject] = [VirtualObject]()
    
    func convertMenuToObject(jsonString: String) {
        menuVirtualObjects.removeAll()
        if let data = jsonString.data(using: .utf8) {
            do {
                let menuItems = try JSONDecoder().decode([MenuItem].self, from: data)
                for menuItem in menuItems {
                    let obj = VirtualObject(modelName: menuItem.itemName, fileExtension: "scn", thumbImageFilename: menuItem.itemName, title: menuItem.itemName, menuItem.itemId)
                    menuVirtualObjects.append(obj)
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
    }
}
