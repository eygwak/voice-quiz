//
//  WordManager.swift
//  VoiceQuiz
//
//  Manages word selection and progression
//

import Foundation

enum WordManagerError: Error {
    case wordsNotLoaded
    case noCategoryFound
    case noWordsAvailable
}

class WordManager {
    private var wordsData: WordsData?
    private var selectedCategory: Category?
    private var availableWords: [Word] = []
    private var usedWordIndices: Set<Int> = []

    private(set) var currentWord: Word?
    private(set) var currentWordIndex: Int = 0

    var hasMoreWords: Bool {
        return usedWordIndices.count < availableWords.count
    }

    var totalWords: Int {
        return availableWords.count
    }

    var wordsCompleted: Int {
        return usedWordIndices.count
    }

    // MARK: - Initialization

    init() {}

    func loadWords(categoryId: String? = nil) throws {
        // Load words.json
        wordsData = try WordsLoader.loadWords()

        // Select category
        if let categoryId = categoryId {
            guard let category = wordsData?.categories.first(where: { $0.id == categoryId }) else {
                throw WordManagerError.noCategoryFound
            }
            selectedCategory = category
        } else {
            // Random category if not specified
            selectedCategory = wordsData?.categories.randomElement()
        }

        guard let category = selectedCategory else {
            throw WordManagerError.noCategoryFound
        }

        guard !category.words.isEmpty else {
            throw WordManagerError.noWordsAvailable
        }

        availableWords = category.words
        usedWordIndices.removeAll()
        currentWordIndex = 0

        print("✅ Loaded \(availableWords.count) words from category: \(category.title)")
    }

    // MARK: - Word Selection

    func nextWord() throws -> Word {
        guard !availableWords.isEmpty else {
            throw WordManagerError.noWordsAvailable
        }

        // Check if we have more words
        guard hasMoreWords else {
            throw WordManagerError.noWordsAvailable
        }

        // Find next unused word
        var randomIndex: Int
        repeat {
            randomIndex = Int.random(in: 0..<availableWords.count)
        } while usedWordIndices.contains(randomIndex)

        // Mark as used
        usedWordIndices.insert(randomIndex)
        currentWordIndex = randomIndex

        let word = availableWords[randomIndex]
        currentWord = word

        print("📝 Next word: \(word.word)")
        return word
    }

    func getCurrentWord() -> Word? {
        return currentWord
    }

    // MARK: - Reset

    func reset() {
        usedWordIndices.removeAll()
        currentWord = nil
        currentWordIndex = 0
    }

    // MARK: - Category Info

    var categoryName: String {
        return selectedCategory?.title ?? "Unknown"
    }

    var categoryId: String {
        return selectedCategory?.id ?? ""
    }

    func getAvailableCategories() -> [Category] {
        return wordsData?.categories ?? []
    }
}
