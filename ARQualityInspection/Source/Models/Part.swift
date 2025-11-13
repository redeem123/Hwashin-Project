//
//  Part.swift
//  ARQualityInspection
//
//  Created for HWASHIN-HUST AR Quality Inspection Project
//  Copyright © 2025-2026 Institute of Energy Technology, HUST
//

import Foundation
import SceneKit

/// Represents a manufactured part with its template and quality data
struct Part: Codable, Identifiable {
    let id: UUID
    let name: String
    let partNumber: String
    let category: String
    let templateURL: URL
    let metadata: PartMetadata
    var scannedData: ScannedPartData?
    var inspectionResults: InspectionResult?

    init(id: UUID = UUID(), name: String, partNumber: String, category: String,
         templateURL: URL, metadata: PartMetadata) {
        self.id = id
        self.name = name
        self.partNumber = partNumber
        self.category = category
        self.templateURL = templateURL
        self.metadata = metadata
    }
}

/// Metadata for a part template
struct PartMetadata: Codable {
    let dimensions: Dimensions
    let tolerances: [Tolerance]
    let material: String
    let createdDate: Date
    let version: String
}

/// Physical dimensions of the part
struct Dimensions: Codable {
    let length: Double
    let width: Double
    let height: Double
    let unit: String // "mm", "cm", "inch"
}

/// Tolerance specification for quality control
struct Tolerance: Codable {
    let id: UUID
    let feature: String
    let nominalValue: Double
    let upperLimit: Double
    let lowerLimit: Double
    let criticalityLevel: CriticalityLevel
}

enum CriticalityLevel: String, Codable {
    case critical
    case major
    case minor
}

/// Scanned data from LiDAR
struct ScannedPartData: Codable {
    let pointCloud: [Point3D]
    let meshData: MeshData
    let scanDate: Date
    let scanQuality: Double // 0.0 to 1.0
    let deviceInfo: DeviceInfo
}

/// 3D point representation
struct Point3D: Codable {
    let x: Double
    let y: Double
    let z: Double
    let confidence: Float
}

/// Mesh data from reconstructed scan
struct MeshData: Codable {
    let vertices: [Point3D]
    let normals: [Point3D]
    let triangles: [Int] // Indices into vertices array
}

/// Device information
struct DeviceInfo: Codable {
    let model: String
    let osVersion: String
    let lidarCapable: Bool
    let scanResolution: String
}

/// Results of quality inspection
struct InspectionResult: Codable {
    let id: UUID
    let partId: UUID
    let inspectionDate: Date
    let overallStatus: InspectionStatus
    let deviationMap: DeviationMap
    let measurements: [Measurement]
    let statistics: InspectionStatistics
    let inspector: String
}

enum InspectionStatus: String, Codable {
    case passed
    case failed
    case conditional
    case pending
}

/// Map of deviations across the part surface
struct DeviationMap: Codable {
    let deviations: [SurfaceDeviation]
    let maxDeviation: Double
    let minDeviation: Double
    let averageDeviation: Double
}

/// Deviation at a specific surface point
struct SurfaceDeviation: Codable {
    let point: Point3D
    let deviation: Double // in mm
    let withinTolerance: Bool
    let heatMapColor: HeatMapColor
}

/// Color coding for heat map visualization
struct HeatMapColor: Codable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float

    /// Generate heat map color based on deviation
    static func from(deviation: Double, maxDeviation: Double) -> HeatMapColor {
        let normalized = min(abs(deviation) / maxDeviation, 1.0)

        // Blue (good) -> Green (ok) -> Yellow (warning) -> Red (bad)
        if normalized < 0.25 {
            let factor = Float(normalized / 0.25)
            return HeatMapColor(red: 0, green: factor, blue: 1.0, alpha: 0.8)
        } else if normalized < 0.5 {
            let factor = Float((normalized - 0.25) / 0.25)
            return HeatMapColor(red: 0, green: 1.0, blue: 1.0 - factor, alpha: 0.8)
        } else if normalized < 0.75 {
            let factor = Float((normalized - 0.5) / 0.25)
            return HeatMapColor(red: factor, green: 1.0, blue: 0, alpha: 0.8)
        } else {
            let factor = Float((normalized - 0.75) / 0.25)
            return HeatMapColor(red: 1.0, green: 1.0 - factor, blue: 0, alpha: 0.8)
        }
    }
}

/// Individual measurement
struct Measurement: Codable {
    let id: UUID
    let feature: String
    let measuredValue: Double
    let nominalValue: Double
    let deviation: Double
    let tolerance: Tolerance
    let passed: Bool
}

/// Statistical summary of inspection
struct InspectionStatistics: Codable {
    let totalPoints: Int
    let pointsInTolerance: Int
    let pointsOutOfTolerance: Int
    let conformancePercentage: Double
    let processingTime: Double // seconds
}
