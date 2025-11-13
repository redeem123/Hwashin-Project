//
//  ObjectRecognitionEngine.swift
//  ARQualityInspection
//
//  Object recognition using machine learning and geometric matching
//  Copyright © 2025-2026 Institute of Energy Technology, HUST
//

import Foundation
import CoreML
import simd

/// Engine for recognizing scanned parts against template database
class ObjectRecognitionEngine {

    // MARK: - Properties

    private let featureExtractor: FeatureExtractor
    private let templateMatcher: TemplateMatcher
    private let poseEstimator: PoseEstimator

    private var templates: [Part] = []
    private let matchingQueue = DispatchQueue(label: "com.hwashin.recognition", qos: .userInitiated)

    // MARK: - Initialization

    init() {
        self.featureExtractor = FeatureExtractor()
        self.templateMatcher = TemplateMatcher()
        self.poseEstimator = PoseEstimator()
    }

    // MARK: - Recognition

    /// Recognize a scanned part against template database
    func recognizePart(
        scannedData: ScannedPartData,
        from templates: [Part],
        completion: @escaping (Result<RecognitionResult, RecognitionError>) -> Void
    ) {
        self.templates = templates

        matchingQueue.async {
            let startTime = Date()

            // Step 1: Extract features from scanned data
            guard let scannedFeatures = self.featureExtractor.extract(from: scannedData) else {
                DispatchQueue.main.async {
                    completion(.failure(.featureExtractionFailed))
                }
                return
            }

            // Step 2: Match against all templates
            var matchResults: [(part: Part, score: Double, pose: Pose)] = []

            for template in templates {
                guard let templateFeatures = self.featureExtractor.extractFromTemplate(template) else {
                    continue
                }

                // Calculate similarity score
                let score = self.templateMatcher.calculateSimilarity(
                    scanned: scannedFeatures,
                    template: templateFeatures
                )

                // Estimate pose if score is above threshold
                if score > 0.5 {
                    if let pose = self.poseEstimator.estimate(
                        scanned: scannedData,
                        template: template
                    ) {
                        matchResults.append((template, score, pose))
                    }
                }
            }

            // Step 3: Sort by score and select best match
            matchResults.sort { $0.score > $1.score }

            guard let bestMatch = matchResults.first, bestMatch.score > 0.7 else {
                DispatchQueue.main.async {
                    completion(.failure(.noMatchFound))
                }
                return
            }

            let processingTime = Date().timeIntervalSince(startTime)

            let result = RecognitionResult(
                recognizedPart: bestMatch.part,
                confidence: bestMatch.score,
                pose: bestMatch.pose,
                alternativeMatches: Array(matchResults.prefix(3).dropFirst()).map { ($0.part, $0.score) },
                processingTime: processingTime
            )

            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }
}

// MARK: - Feature Extraction

/// Extracts geometric features from 3D data
class FeatureExtractor {

    /// Extract features from scanned data
    func extract(from scannedData: ScannedPartData) -> GeometricFeatures? {
        let pointCloud = scannedData.pointCloud

        guard !pointCloud.isEmpty else { return nil }

        // Calculate bounding box
        let boundingBox = calculateBoundingBox(pointCloud: pointCloud)

        // Calculate surface area (approximate)
        let surfaceArea = estimateSurfaceArea(mesh: scannedData.meshData)

        // Calculate volume (approximate)
        let volume = estimateVolume(mesh: scannedData.meshData)

        // Extract shape descriptors
        let shapeDescriptor = extractShapeDescriptor(pointCloud: pointCloud)

        // Calculate curvature statistics
        let curvatureStats = analyzeCurvature(mesh: scannedData.meshData)

        return GeometricFeatures(
            boundingBox: boundingBox,
            surfaceArea: surfaceArea,
            volume: volume,
            shapeDescriptor: shapeDescriptor,
            curvatureStatistics: curvatureStats
        )
    }

    /// Extract features from template part
    func extractFromTemplate(_ template: Part) -> GeometricFeatures? {
        // In a real implementation, this would load and process the CAD model
        // For now, we'll use metadata
        let dims = template.metadata.dimensions

        let boundingBox = BoundingBox(
            minX: 0, maxX: dims.length,
            minY: 0, maxY: dims.width,
            minZ: 0, maxZ: dims.height
        )

        // Approximate surface area and volume from dimensions
        let surfaceArea = 2 * (dims.length * dims.width + dims.width * dims.height + dims.height * dims.length)
        let volume = dims.length * dims.width * dims.height

        return GeometricFeatures(
            boundingBox: boundingBox,
            surfaceArea: surfaceArea,
            volume: volume,
            shapeDescriptor: [],
            curvatureStatistics: CurvatureStatistics(mean: 0, variance: 0, max: 0, min: 0)
        )
    }

    // Helper methods

    private func calculateBoundingBox(pointCloud: [Point3D]) -> BoundingBox {
        var minX = Double.infinity, maxX = -Double.infinity
        var minY = Double.infinity, maxY = -Double.infinity
        var minZ = Double.infinity, maxZ = -Double.infinity

        for point in pointCloud {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }

        return BoundingBox(minX: minX, maxX: maxX, minY: minY, maxY: maxY, minZ: minZ, maxZ: maxZ)
    }

    private func estimateSurfaceArea(mesh: MeshData) -> Double {
        var totalArea = 0.0

        for i in stride(from: 0, to: mesh.triangles.count, by: 3) {
            let i1 = mesh.triangles[i]
            let i2 = mesh.triangles[i + 1]
            let i3 = mesh.triangles[i + 2]

            let v1 = mesh.vertices[i1]
            let v2 = mesh.vertices[i2]
            let v3 = mesh.vertices[i3]

            // Calculate triangle area using cross product
            let edge1 = SIMD3<Double>(v2.x - v1.x, v2.y - v1.y, v2.z - v1.z)
            let edge2 = SIMD3<Double>(v3.x - v1.x, v3.y - v1.y, v3.z - v1.z)
            let cross = simd_cross(edge1, edge2)
            let area = simd_length(cross) / 2.0

            totalArea += area
        }

        return totalArea
    }

    private func estimateVolume(mesh: MeshData) -> Double {
        // Simplified volume calculation using divergence theorem
        var volume = 0.0

        for i in stride(from: 0, to: mesh.triangles.count, by: 3) {
            let i1 = mesh.triangles[i]
            let i2 = mesh.triangles[i + 1]
            let i3 = mesh.triangles[i + 2]

            let v1 = mesh.vertices[i1]
            let v2 = mesh.vertices[i2]
            let v3 = mesh.vertices[i3]

            volume += v1.x * (v2.y * v3.z - v3.y * v2.z)
        }

        return abs(volume) / 6.0
    }

    private func extractShapeDescriptor(pointCloud: [Point3D]) -> [Double] {
        // Simplified shape descriptor (in reality, use more sophisticated descriptors like FPFH, SHOT, etc.)
        var descriptor: [Double] = []

        // Calculate centroid
        let centroid = pointCloud.reduce(Point3D(x: 0, y: 0, z: 0, confidence: 0)) {
            Point3D(x: $0.x + $1.x, y: $0.y + $1.y, z: $0.z + $1.z, confidence: 0)
        }
        let count = Double(pointCloud.count)
        let avgX = centroid.x / count
        let avgY = centroid.y / count
        let avgZ = centroid.z / count

        // Distance histogram from centroid
        var distanceHistogram = [Double](repeating: 0, count: 10)
        for point in pointCloud {
            let dx = point.x - avgX
            let dy = point.y - avgY
            let dz = point.z - avgZ
            let distance = sqrt(dx*dx + dy*dy + dz*dz)

            let bin = min(Int(distance * 10), 9)
            distanceHistogram[bin] += 1
        }

        descriptor.append(contentsOf: distanceHistogram.map { $0 / count })

        return descriptor
    }

    private func analyzeCurvature(mesh: MeshData) -> CurvatureStatistics {
        // Simplified curvature analysis
        var curvatures: [Double] = []

        for i in 0..<mesh.vertices.count {
            // Simple curvature approximation based on normal deviation
            let curvature = abs(mesh.normals[i].z) // Simplified
            curvatures.append(curvature)
        }

        let mean = curvatures.reduce(0, +) / Double(curvatures.count)
        let variance = curvatures.map { pow($0 - mean, 2) }.reduce(0, +) / Double(curvatures.count)
        let max = curvatures.max() ?? 0
        let min = curvatures.min() ?? 0

        return CurvatureStatistics(mean: mean, variance: variance, max: max, min: min)
    }
}

// MARK: - Template Matching

/// Matches geometric features against templates
class TemplateMatcher {

    /// Calculate similarity between scanned and template features
    func calculateSimilarity(scanned: GeometricFeatures, template: GeometricFeatures) -> Double {
        var totalScore = 0.0
        var weights = 0.0

        // Bounding box similarity (30% weight)
        let bboxScore = compareBoundingBoxes(scanned.boundingBox, template.boundingBox)
        totalScore += bboxScore * 0.3
        weights += 0.3

        // Surface area similarity (20% weight)
        let areaScore = compareValues(scanned.surfaceArea, template.surfaceArea)
        totalScore += areaScore * 0.2
        weights += 0.2

        // Volume similarity (20% weight)
        let volumeScore = compareValues(scanned.volume, template.volume)
        totalScore += volumeScore * 0.2
        weights += 0.2

        // Shape descriptor similarity (30% weight)
        let shapeScore = compareShapeDescriptors(scanned.shapeDescriptor, template.shapeDescriptor)
        totalScore += shapeScore * 0.3
        weights += 0.3

        return totalScore / weights
    }

    private func compareBoundingBoxes(_ bbox1: BoundingBox, _ bbox2: BoundingBox) -> Double {
        let dim1 = [bbox1.maxX - bbox1.minX, bbox1.maxY - bbox1.minY, bbox1.maxZ - bbox1.minZ]
        let dim2 = [bbox2.maxX - bbox2.minX, bbox2.maxY - bbox2.minY, bbox2.maxZ - bbox2.minZ]

        var score = 0.0
        for i in 0..<3 {
            score += compareValues(dim1[i], dim2[i])
        }

        return score / 3.0
    }

    private func compareValues(_ v1: Double, _ v2: Double) -> Double {
        let ratio = min(v1, v2) / max(v1, v2)
        return ratio
    }

    private func compareShapeDescriptors(_ desc1: [Double], _ desc2: [Double]) -> Double {
        guard desc1.count == desc2.count else { return 0.0 }

        // Calculate cosine similarity
        let dotProduct = zip(desc1, desc2).map(*).reduce(0, +)
        let magnitude1 = sqrt(desc1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(desc2.map { $0 * $0 }.reduce(0, +))

        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }

        return dotProduct / (magnitude1 * magnitude2)
    }
}

// MARK: - Pose Estimation

/// Estimates 6DOF pose of recognized object
class PoseEstimator {

    func estimate(scanned: ScannedPartData, template: Part) -> Pose? {
        // Simplified pose estimation using ICP (Iterative Closest Point) concept

        // Calculate centroids
        let scannedCentroid = calculateCentroid(scanned.pointCloud)
        let templateDims = template.metadata.dimensions
        let templateCentroid = Point3D(
            x: templateDims.length / 2,
            y: templateDims.width / 2,
            z: templateDims.height / 2,
            confidence: 1.0
        )

        // Translation is difference in centroids
        let translation = SIMD3<Double>(
            scannedCentroid.x - templateCentroid.x,
            scannedCentroid.y - templateCentroid.y,
            scannedCentroid.z - templateCentroid.z
        )

        // For rotation, simplified to identity (in real implementation, use ICP or feature matching)
        let rotation = simd_quatd(angle: 0, axis: SIMD3<Double>(0, 1, 0))

        return Pose(translation: translation, rotation: rotation)
    }

    private func calculateCentroid(_ pointCloud: [Point3D]) -> Point3D {
        let sum = pointCloud.reduce(Point3D(x: 0, y: 0, z: 0, confidence: 0)) {
            Point3D(x: $0.x + $1.x, y: $0.y + $1.y, z: $0.z + $1.z, confidence: 0)
        }
        let count = Double(pointCloud.count)
        return Point3D(x: sum.x / count, y: sum.y / count, z: sum.z / count, confidence: 1.0)
    }
}

// MARK: - Supporting Types

struct GeometricFeatures {
    let boundingBox: BoundingBox
    let surfaceArea: Double
    let volume: Double
    let shapeDescriptor: [Double]
    let curvatureStatistics: CurvatureStatistics
}

struct BoundingBox {
    let minX: Double, maxX: Double
    let minY: Double, maxY: Double
    let minZ: Double, maxZ: Double
}

struct CurvatureStatistics {
    let mean: Double
    let variance: Double
    let max: Double
    let min: Double
}

struct Pose {
    let translation: SIMD3<Double>
    let rotation: simd_quatd
}

struct RecognitionResult {
    let recognizedPart: Part
    let confidence: Double
    let pose: Pose
    let alternativeMatches: [(Part, Double)]
    let processingTime: TimeInterval
}

enum RecognitionError: Error, LocalizedError {
    case featureExtractionFailed
    case noMatchFound
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .featureExtractionFailed:
            return "Failed to extract features from scanned data"
        case .noMatchFound:
            return "No matching template found in database"
        case .insufficientData:
            return "Insufficient scan data for recognition"
        }
    }
}
