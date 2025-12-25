//
//  APIClient.swift
//  VoiceQuiz
//
//  REST API client for Cloud Run backend
//

import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)
}

class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://voicequiz-server-985594867462.asia-northeast3.run.app"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Mode A: AI Describes

    /// Request AI description for a word
    /// - Parameters:
    ///   - word: The target word to describe
    ///   - taboo: Taboo words that AI should not use
    ///   - previousHints: Previous hints already given (for additional hints)
    /// - Returns: AI description text
    func requestDescription(
        word: String,
        taboo: [String],
        previousHints: [String] = []
    ) async throws -> String {
        let url = URL(string: "\(baseURL)/modeA/describe")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "word": word,
            "taboo": taboo,
            "previousHints": previousHints
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let text = json?["text"] as? String else {
                throw APIError.decodingError(NSError(domain: "APIClient", code: -1))
            }

            return text

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Mode B: AI Guesses

    /// Request AI guess based on user description
    /// - Parameters:
    ///   - transcriptSoFar: User's description transcript
    ///   - category: Word category for context
    ///   - previousGuesses: Previous guesses already made
    /// - Returns: AI guess text
    func requestGuess(
        transcriptSoFar: String,
        category: String,
        previousGuesses: [String] = []
    ) async throws -> String {
        let url = URL(string: "\(baseURL)/modeB/guess")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "transcriptSoFar": transcriptSoFar,
            "category": category,
            "previousGuesses": previousGuesses
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let guessText = json?["guessText"] as? String else {
                throw APIError.decodingError(NSError(domain: "APIClient", code: -1))
            }

            return guessText

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Health Check

    /// Check if backend is healthy
    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            guard httpResponse.statusCode == 200 else {
                return false
            }

            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["status"] as? String == "ok"

        } catch {
            return false
        }
    }
}
