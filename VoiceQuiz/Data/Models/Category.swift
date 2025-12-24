//
//  Category.swift
//  VoiceQuiz
//
//  Data model for word categories
//

import Foundation

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let words: [Word]
}

struct WordsData: Codable {
    let version: Int
    let generated_at: String
    let categories: [Category]
}
