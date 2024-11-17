//
//  AICenter.swift
//  ARKitProject
//
//  Created by Tao, Wang on 2024/11/17.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

let prefixPrompt = "As a nutritionist, please help me analyze the nutritional content of the following foods and give me some brief dietary recommendations. The word limit is 100 words\n"

// AICenter: 用于智能分析菜品营养并提供膳食建议
class AICenter {
    // MARK: - Singleton Instance
    static let shared = AICenter()
    let openAI = DoubaoAI(config: DoubaoAI.Config.makeDefaultOpenAI())
    private var analyzingItem: VirtualObject?
    private init() {}
    
    // MARK: - Public Method
    func analyzeItem(
        item: VirtualObject,
        completion: @escaping (Result<ItemAnalysisResult, Error>) -> Void
    ) {
        if let analyzingItem = analyzingItem, analyzingItem.id == item.id {
            completion(.failure(NSError(domain: "Repeat analyze item", code: -1, userInfo: nil)))
        }
        var prompt = prefixPrompt + "food name: hamburger"
        
        let chat: [Message] = [
            systemUserMessage(),
            Message(content: prompt, role: "user")
            ]

        openAI.sendChat(chat, completionHandler: { result in
            switch result {
                case .success(let success):
                let resultText = success.choices.first?.message.content ?? ""
                print(resultText)
                let itemAnalysisResult = ItemAnalysisResult(item: item, suggestions: [resultText])
                completion(.success(itemAnalysisResult))
                case .failure(let failure):
                print(failure.localizedDescription)
                completion(.failure(failure))
                }
        })
    }
    
    func analyzeOrder(order: String, items: [VirtualObject], completion:@escaping (Result<OrderAnalysisResult, Error>) -> Void) {
        var prompt = prefixPrompt
        items.forEach { obj in
            prompt.append(obj.title + "\n")
        }
        
        let chat: [Message] = [
            Message(content: "You are a helpful nutritionist", role: "system"),
            Message(content: prompt, role: "user")
            ]

        openAI.sendChat(chat, completionHandler: { result in
            switch result {
                case .success(let success):
                let resultText = success.choices.first?.message.content ?? ""
                print(resultText)
                let orderAnalysisResult = OrderAnalysisResult(order: order, suggestions: [resultText])
                completion(.success(orderAnalysisResult))
                case .failure(let failure):
                print(failure.localizedDescription)
                completion(.failure(failure))
                }
        })
    }
    
    func systemUserMessage() -> Message {
        Message(content: "You are a professional nutritionist, very good at analyzing food nutritional ingredients and content. Please talk to me in a very professional tone.", role: "system")
    }
}

struct ItemAnalysisResult {
    let item: VirtualObject
    let suggestions: [String]
    
    func suggestionDescription() -> String {
        var suggestion = "Item name: \(item.title)\n"
        suggestions.forEach { text in
            suggestion.append("\(text)\n")
        }
        return suggestion;
    }
}

struct OrderAnalysisResult {
    let order: String
    let suggestions: [String]
    
    func suggestionDescription() -> String {
        var suggestion = "\(order):\n"
        suggestions.forEach { text in
            suggestion.append("\(text)\n")
        }
        return suggestion;
    }
}
    
