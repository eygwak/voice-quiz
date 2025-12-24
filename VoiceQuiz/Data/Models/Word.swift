//
//  Word.swift
//  VoiceQuiz
//
//  Data model for quiz words
//

import Foundation

struct Word: Codable, Identifiable, Hashable {
    var id: String { word }

    let word: String
    let synonyms: [String]
    let difficulty: Int
    let taboo: [String]
}
