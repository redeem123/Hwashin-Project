//
//  TemplateDatabaseManager.swift
//  ARQualityInspection
//
//  Template database management system
//  Copyright © 2025-2026 Institute of Energy Technology, HUST
//

import Foundation
import CoreData
import SceneKit

/// Manages CAD template database for part recognition and comparison
class TemplateDatabaseManager {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let databaseDirectory: URL
    private var cachedTemplates: [UUID: Part] = [:]

    // Supported CAD file formats
    private let supportedFormats = ["stl", "obj", "step", "stp", "usd", "usda", "usdc"]

    // MARK: - Initialization

    init() {
        // Set up database directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.databaseDirectory = documentsPath.appendingPathComponent("Templates")

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)

        // Load cached templates
        loadAllTemplates()
    }

    // MARK: - Template Management

    /// Import a CAD template file
    func importTemplate(
        from fileURL: URL,
        name: String,
        partNumber: String,
        category: String,
        metadata: PartMetadata,
        completion: @escaping (Result<Part, DatabaseError>) -> Void
    ) {
        // Validate file format
        let fileExtension = fileURL.pathExtension.lowercased()
        guard supportedFormats.contains(fileExtension) else {
            completion(.failure(.unsupportedFormat(fileExtension)))
            return
        }

        // Copy file to database directory
        let destinationURL = databaseDirectory
            .appendingPathComponent(partNumber)
            .appendingPathExtension(fileExtension)

        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Copy new file
            try fileManager.copyItem(at: fileURL, to: destinationURL)

            // Create Part object
            let part = Part(
                name: name,
                partNumber: partNumber,
                category: category,
                templateURL: destinationURL,
                metadata: metadata
            )

            // Save to cache
            cachedTemplates[part.id] = part

            // Save to persistent storage
            saveTemplate(part)

            completion(.success(part))
        } catch {
            completion(.failure(.importFailed(error)))
        }
    }

    /// Retrieve template by ID
    func getTemplate(id: UUID) -> Part? {
        return cachedTemplates[id]
    }

    /// Retrieve template by part number
    func getTemplate(partNumber: String) -> Part? {
        return cachedTemplates.values.first { $0.partNumber == partNumber }
    }

    /// Get all templates
    func getAllTemplates() -> [Part] {
        return Array(cachedTemplates.values)
    }

    /// Get templates by category
    func getTemplates(category: String) -> [Part] {
        return cachedTemplates.values.filter { $0.category == category }
    }

    /// Search templates
    func searchTemplates(query: String) -> [Part] {
        let lowercaseQuery = query.lowercased()
        return cachedTemplates.values.filter {
            $0.name.lowercased().contains(lowercaseQuery) ||
            $0.partNumber.lowercased().contains(lowercaseQuery) ||
            $0.category.lowercased().contains(lowercaseQuery)
        }
    }

    /// Delete template
    func deleteTemplate(id: UUID, completion: @escaping (Result<Void, DatabaseError>) -> Void) {
        guard let part = cachedTemplates[id] else {
            completion(.failure(.templateNotFound))
            return
        }

        do {
            // Delete file
            if fileManager.fileExists(atPath: part.templateURL.path) {
                try fileManager.removeItem(at: part.templateURL)
            }

            // Remove from cache
            cachedTemplates.removeValue(forKey: id)

            // Remove from persistent storage
            removeTemplateFromStorage(id)

            completion(.success(()))
        } catch {
            completion(.failure(.deleteFailed(error)))
        }
    }

    /// Update template metadata
    func updateTemplate(_ part: Part) {
        cachedTemplates[part.id] = part
        saveTemplate(part)
    }

    // MARK: - CAD Model Loading

    /// Load 3D geometry from CAD file
    func loadGeometry(for part: Part) -> SCNNode? {
        let fileURL = part.templateURL
        let fileExtension = fileURL.pathExtension.lowercased()

        switch fileExtension {
        case "stl":
            return loadSTL(from: fileURL)
        case "obj":
            return loadOBJ(from: fileURL)
        case "usd", "usda", "usdc":
            return loadUSD(from: fileURL)
        default:
            return nil
        }
    }

    /// Load STL file
    private func loadSTL(from url: URL) -> SCNNode? {
        // STL loading implementation
        // This is a simplified version - actual implementation would parse binary/ASCII STL
        guard let scene = try? SCNScene(url: url, options: nil) else {
            return nil
        }
        return scene.rootNode
    }

    /// Load OBJ file
    private func loadOBJ(from url: URL) -> SCNNode? {
        // OBJ is natively supported by SceneKit
        guard let scene = try? SCNScene(url: url, options: [
            .convertToYUp: true,
            .createNormalsIfAbsent: true
        ]) else {
            return nil
        }
        return scene.rootNode
    }

    /// Load USD file
    private func loadUSD(from url: URL) -> SCNNode? {
        // USD is supported on iOS 14+
        if #available(iOS 14.0, *) {
            guard let scene = try? SCNScene(url: url, options: nil) else {
                return nil
            }
            return scene.rootNode
        }
        return nil
    }

    // MARK: - Persistence

    /// Save template to persistent storage
    private func saveTemplate(_ part: Part) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(part) else { return }

        let metadataURL = databaseDirectory
            .appendingPathComponent(part.id.uuidString)
            .appendingPathExtension("json")

        try? data.write(to: metadataURL)
    }

    /// Load all templates from storage
    private func loadAllTemplates() {
        guard let enumerator = fileManager.enumerator(
            at: databaseDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }

            if let data = try? Data(contentsOf: fileURL),
               let part = try? decoder.decode(Part.self, from: data) {
                cachedTemplates[part.id] = part
            }
        }
    }

    /// Remove template from storage
    private func removeTemplateFromStorage(_ id: UUID) {
        let metadataURL = databaseDirectory
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension("json")

        try? fileManager.removeItem(at: metadataURL)
    }

    // MARK: - Batch Operations

    /// Import multiple templates
    func batchImport(
        templates: [(fileURL: URL, name: String, partNumber: String, category: String, metadata: PartMetadata)],
        progressHandler: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<[Part], DatabaseError>) -> Void
    ) {
        var importedParts: [Part] = []
        var currentIndex = 0

        let dispatchGroup = DispatchGroup()

        for templateInfo in templates {
            dispatchGroup.enter()

            importTemplate(
                from: templateInfo.fileURL,
                name: templateInfo.name,
                partNumber: templateInfo.partNumber,
                category: templateInfo.category,
                metadata: templateInfo.metadata
            ) { result in
                switch result {
                case .success(let part):
                    importedParts.append(part)
                case .failure:
                    break
                }

                currentIndex += 1
                progressHandler(currentIndex, templates.count)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(.success(importedParts))
        }
    }

    // MARK: - Database Statistics

    func getDatabaseStatistics() -> DatabaseStatistics {
        let totalTemplates = cachedTemplates.count
        let categories = Set(cachedTemplates.values.map { $0.category })

        var totalSize: UInt64 = 0
        for part in cachedTemplates.values {
            if let attributes = try? fileManager.attributesOfItem(atPath: part.templateURL.path),
               let fileSize = attributes[.size] as? UInt64 {
                totalSize += fileSize
            }
        }

        return DatabaseStatistics(
            totalTemplates: totalTemplates,
            categories: Array(categories),
            totalStorageSize: totalSize,
            lastUpdated: Date()
        )
    }
}

// MARK: - Supporting Types

struct DatabaseStatistics {
    let totalTemplates: Int
    let categories: [String]
    let totalStorageSize: UInt64
    let lastUpdated: Date

    var storageSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalStorageSize))
    }
}

enum DatabaseError: Error, LocalizedError {
    case unsupportedFormat(String)
    case importFailed(Error)
    case templateNotFound
    case deleteFailed(Error)
    case loadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported file format: .\(format)"
        case .importFailed(let error):
            return "Failed to import template: \(error.localizedDescription)"
        case .templateNotFound:
            return "Template not found in database"
        case .deleteFailed(let error):
            return "Failed to delete template: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load template: \(error.localizedDescription)"
        }
    }
}
