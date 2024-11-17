//
//  DoubaoAI.swift
//  ARKitProject
//
//  Created by Tao, Wang on 2024/11/17.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

public class DoubaoAI {
    fileprivate let config: Config

    /// Configuration object for the client
    public struct Config {
        
        /// Initialiser
        public init(baseURL: String, apiKey: String, model: String, session: URLSession) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.model = model
            self.session = session
        }
        let baseURL: String
        let apiKey: String
        let model: String
        let session:URLSession
        
        public static func makeDefaultOpenAI() -> Self {
            .init(baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
                  apiKey: "6357ba36-d08a-4273-b4ac-102de767a80c",
                  model: "ep-20241117171725-lblwx",
                  session: .shared)
        }
    }
    
    public init(config: Config) {
        self.config = config
    }
}

extension DoubaoAI {
    /// Send a Completion to the OpenAI API
    public func sendChat(_ chat:[Message], completionHandler: @escaping (Result<ChatCompletionResponse, OpenAIError>) -> Void) {
        let request = prepareRequest(chat)
        
        makeRequest(request: request) { result in
            switch result {
            case .success(let success):
                do {
                    let res = try JSONDecoder().decode(ChatCompletionResponse.self, from: success)
                    print("DoubaoAI sendChat reponse: \(String(describing: res.choices.first?.message.content))")
                    completionHandler(.success(res))
                } catch {
                    completionHandler(.failure(.decodingError(error: error)))
                }
            case .failure(let failure):
                completionHandler(.failure(.genericError(error: failure)))
            }
        }
    }
}

extension DoubaoAI {
    private func prepareRequest(_ chat: [Message]) -> URLRequest {
        var urlComponents = URLComponents(url: URL(string: config.baseURL)!, resolvingAgainstBaseURL: true)
        var request = URLRequest(url: urlComponents!.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        
        let body = HttpChatBody(model: config.model, messages: chat)
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(body) {
            request.httpBody = encoded
        }
        
        return request
    }
    
    private func makeRequest(request: URLRequest, completionHandler: @escaping (Result<Data, Error>) -> Void) {
        let session = config.session
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completionHandler(.failure(error))
            } else if let data = data {
                completionHandler(.success(data))
            }
        }
        
        task.resume()
    }
}

// Root Response Structure
public struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    let created: Int
    let id: String
    let model: String
    let object: String
    let usage: Usage
}

// Choice Object
struct Choice: Codable {
    let finishReason: String
    let index: Int
    let logprobs: Logprobs?
    let message: Message

    enum CodingKeys: String, CodingKey {
        case finishReason = "finish_reason"
        case index, logprobs, message
    }
}

// Message Object
public struct Message: Codable {
    let content: String
    let role: String
}

struct HttpChatBody: Codable {
    let model: String
    let messages: [Message]
}

// Usage Object
struct Usage: Codable {
    let completionTokens: Int
    let promptTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case completionTokens = "completion_tokens"
        case promptTokens = "prompt_tokens"
        case totalTokens = "total_tokens"
    }
}

// Logprobs (null in the example but included for completeness)
struct Logprobs: Codable {
    // Define fields if necessary when the structure is known
}

public enum OpenAIError: Error {
    case genericError(error: Error)
    case decodingError(error: Error)
    case chatError(error: Error)
}

