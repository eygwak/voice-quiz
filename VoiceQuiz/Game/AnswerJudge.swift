//
//  AnswerJudge.swift
//  VoiceQuiz
//
//  Answer judgment logic for Mode A using Levenshtein distance
//

import Foundation

enum JudgmentResult {
    case correct    // Exact match, synonym, or similarity ≥ 0.90
    case close      // Similarity 0.80 ~ 0.89
    case incorrect  // Similarity < 0.80

    var feedback: String {
        switch self {
        case .correct:
            return "Correct!"
        case .close:
            return "Close!"
        case .incorrect:
            return "Try again!"
        }
    }

    var color: String {
        switch self {
        case .correct:
            return "green"
        case .close:
            return "orange"
        case .incorrect:
            return "red"
        }
    }
}

class AnswerJudge {
    private let correctThreshold: Double = 0.90
    private let closeThreshold: Double = 0.80

    // MARK: - Public Interface

    func judge(userAnswer: String, correctWord: Word) -> JudgmentResult {
        let normalizedAnswer = normalize(userAnswer)
        let normalizedTarget = normalize(correctWord.word)

        // Check exact match
        if normalizedAnswer == normalizedTarget {
            return .correct
        }

        // Check synonyms
        for synonym in correctWord.synonyms {
            if normalizedAnswer == normalize(synonym) {
                return .correct
            }
        }

        // Calculate similarity
        let similarity = calculateSimilarity(normalizedAnswer, normalizedTarget)

        // Judge based on similarity
        if similarity >= correctThreshold {
            return .correct
        } else if similarity >= closeThreshold {
            return .close
        } else {
            return .incorrect
        }
    }

    // MARK: - String Normalization

    private func normalize(_ string: String) -> String {
        var normalized = string.lowercased()

        // Remove punctuation
        let punctuation = CharacterSet.punctuationCharacters
        normalized = normalized.components(separatedBy: punctuation).joined()

        // Trim whitespace
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove extra spaces
        normalized = normalized.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return normalized
    }

    // MARK: - Similarity Calculation

    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        guard !s1.isEmpty && !s2.isEmpty else { return 0.0 }

        let distance = levenshteinDistance(s1, s2)
        let maxLength = Double(max(s1.count, s2.count))

        // Normalize to 0.0 ~ 1.0
        let similarity = 1.0 - (Double(distance) / maxLength)

        return max(0.0, min(1.0, similarity))
    }

    // MARK: - Levenshtein Distance

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        let m = s1Array.count
        let n = s2Array.count

        // Create distance matrix
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        // Initialize first row and column
        for i in 0...m {
            matrix[i][0] = i
        }
        for j in 0...n {
            matrix[0][j] = j
        }

        // Fill matrix
        for i in 1...m {
            for j in 1...n {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,      // deletion
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }

        return matrix[m][n]
    }
}
