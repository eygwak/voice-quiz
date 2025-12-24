//
//  WordsLoader.swift
//  VoiceQuiz
//
//  Utility to load words.json from bundle
//

import Foundation

enum WordsLoaderError: Error {
    case fileNotFound
    case invalidJSON
}

class WordsLoader {
    static func loadWords() throws -> WordsData {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            throw WordsLoaderError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(WordsData.self, from: data)
    }

    static func loadWordsAsync() async throws -> WordsData {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            throw WordsLoaderError.fileNotFound
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(WordsData.self, from: data)
    }
}
