//
//  HistoryManager.swift
//  VoiceQuiz
//
//  Game session history file persistence manager
//

import Foundation

enum HistoryManagerError: Error {
    case fileNotFound
    case encodingFailed
    case decodingFailed
    case saveFailed
    case deleteFailed
}

class HistoryManager {
    static let shared = HistoryManager()

    private let fileManager = FileManager.default
    private let historyDirectory = "GameHistory"

    private var documentsDirectory: URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var historyDirectoryURL: URL {
        return documentsDirectory.appendingPathComponent(historyDirectory)
    }

    private init() {
        createHistoryDirectoryIfNeeded()
    }

    // MARK: - Directory Setup

    private func createHistoryDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: historyDirectoryURL.path) {
            do {
                try fileManager.createDirectory(
                    at: historyDirectoryURL,
                    withIntermediateDirectories: true
                )
                print("✅ Created history directory: \(historyDirectoryURL.path)")
            } catch {
                print("❌ Failed to create history directory: \(error)")
            }
        }
    }

    // MARK: - Save Session

    func saveSession(_ session: GameSession) throws {
        let filename = "game_session_\(session.id).json"
        let fileURL = historyDirectoryURL.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(session)
            try data.write(to: fileURL)

            print("💾 Saved game session: \(filename)")

            // Update metadata in UserDefaults
            let metadata = session.toMetadata()
            UserDefaultsManager.shared.addHistoryMetadata(metadata)

        } catch {
            print("❌ Failed to save session: \(error)")
            throw HistoryManagerError.saveFailed
        }
    }

    // MARK: - Load Session

    func loadSession(id: String) throws -> GameSession {
        let filename = "game_session_\(id).json"
        let fileURL = historyDirectoryURL.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw HistoryManagerError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let session = try decoder.decode(GameSession.self, from: data)
            return session

        } catch {
            print("❌ Failed to load session: \(error)")
            throw HistoryManagerError.decodingFailed
        }
    }

    // MARK: - Load Recent Sessions

    func loadRecentSessions(limit: Int = 10) -> [GameSession] {
        let metadata = UserDefaultsManager.shared.getHistoryMetadata()
        let recentMetadata = Array(metadata.prefix(limit))

        var sessions: [GameSession] = []

        for meta in recentMetadata {
            do {
                let session = try loadSession(id: meta.id)
                sessions.append(session)
            } catch {
                print("⚠️ Failed to load session \(meta.id): \(error)")
            }
        }

        return sessions
    }

    // MARK: - Delete Session

    func deleteSession(id: String) throws {
        let filename = "game_session_\(id).json"
        let fileURL = historyDirectoryURL.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw HistoryManagerError.fileNotFound
        }

        do {
            try fileManager.removeItem(at: fileURL)
            print("🗑️ Deleted session: \(filename)")

            // Update metadata
            var metadata = UserDefaultsManager.shared.getHistoryMetadata()
            metadata.removeAll { $0.id == id }
            UserDefaultsManager.shared.saveHistoryMetadata(metadata)

        } catch {
            print("❌ Failed to delete session: \(error)")
            throw HistoryManagerError.deleteFailed
        }
    }

    // MARK: - Delete All Sessions

    func deleteAllSessions() throws {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: historyDirectoryURL,
                includingPropertiesForKeys: nil
            )

            for fileURL in fileURLs where fileURL.pathExtension == "json" {
                try fileManager.removeItem(at: fileURL)
            }

            UserDefaultsManager.shared.clearHistoryMetadata()
            print("🗑️ Deleted all game sessions")

        } catch {
            print("❌ Failed to delete all sessions: \(error)")
            throw HistoryManagerError.deleteFailed
        }
    }

    // MARK: - Storage Management

    func cleanupOldSessions(keepCount: Int = 100) {
        let metadata = UserDefaultsManager.shared.getHistoryMetadata()

        guard metadata.count > keepCount else { return }

        let toDelete = metadata.suffix(from: keepCount)

        for meta in toDelete {
            do {
                try deleteSession(id: meta.id)
            } catch {
                print("⚠️ Failed to delete old session \(meta.id): \(error)")
            }
        }

        print("🧹 Cleaned up \(toDelete.count) old sessions")
    }

    // MARK: - Debug

    func listAllSessions() {
        let metadata = UserDefaultsManager.shared.getHistoryMetadata()
        print("📋 Total sessions: \(metadata.count)")

        for meta in metadata.prefix(10) {
            print("  - \(meta.id): \(meta.mode) | Score: \(meta.score) | \(meta.date)")
        }
    }

    func getStorageSize() -> String {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: historyDirectoryURL,
                includingPropertiesForKeys: [.fileSizeKey]
            )

            var totalSize: Int64 = 0
            for fileURL in fileURLs {
                let fileAttributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let fileSize = fileAttributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)

        } catch {
            print("❌ Failed to calculate storage size: \(error)")
            return "Unknown"
        }
    }
}
