//
//  GeometricComparisonEngine.swift
//  ARQualityInspection
//
//  Engine for comparing scanned geometry with CAD templates
//  Copyright © 2025-2026 Institute of Energy Technology, HUST
//

import Foundation
import simd
import Accelerate

/// Engine for geometric comparison and deviation analysis
class GeometricComparisonEngine {

    // MARK: - Properties

    private let comparisonQueue = DispatchQueue(label: "com.hwashin.comparison", qos: .userInitiated)
    private let maxDeviation: Double = 5.0 // mm

    // MARK: - Comparison

    /// Compare scanned part with template and generate deviation map
    func compare(
        scannedData: ScannedPartData,
        template: Part,
        templateGeometry: SCNNode,
        pose: Pose,
        completion: @escaping (Result<InspectionResult, ComparisonError>) -> Void
    ) {
        comparisonQueue.async {
            let startTime = Date()

            // Step 1: Transform scanned data to template coordinate system
            let transformedPoints = self.transformPoints(
                scannedData.pointCloud,
                withPose: pose
            )

            // Step 2: Calculate point-to-surface distances
            guard let deviations = self.calculateDeviations(
                points: transformedPoints,
                templateGeometry: templateGeometry
            ) else {
                DispatchQueue.main.async {
                    completion(.failure(.calculationFailed))
                }
                return
            }

            // Step 3: Generate deviation map
            let deviationMap = self.generateDeviationMap(
                deviations: deviations,
                tolerances: template.metadata.tolerances
            )

            // Step 4: Perform dimensional measurements
            let measurements = self.performMeasurements(
                scannedData: scannedData,
                template: template,
                deviations: deviations
            )

            // Step 5: Calculate statistics
            let statistics = self.calculateStatistics(
                deviations: deviations,
                measurements: measurements,
                startTime: startTime
            )

            // Step 6: Determine overall status
            let status = self.determineInspectionStatus(
                deviationMap: deviationMap,
                measurements: measurements
            )

            // Create inspection result
            let result = InspectionResult(
                id: UUID(),
                partId: template.id,
                inspectionDate: Date(),
                overallStatus: status,
                deviationMap: deviationMap,
                measurements: measurements,
                statistics: statistics,
                inspector: "AR System"
            )

            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }

    // MARK: - Transformation

    /// Transform point cloud to template coordinate system
    private func transformPoints(_ points: [Point3D], withPose pose: Pose) -> [Point3D] {
        return points.map { point in
            let position = SIMD3<Double>(point.x, point.y, point.z)

            // Apply rotation
            let rotated = pose.rotation.act(position)

            // Apply translation
            let transformed = rotated + pose.translation

            return Point3D(
                x: transformed.x,
                y: transformed.y,
                z: transformed.z,
                confidence: point.confidence
            )
        }
    }

    // MARK: - Deviation Calculation

    /// Calculate point-to-surface distances
    private func calculateDeviations(
        points: [Point3D],
        templateGeometry: SCNNode
    ) -> [SurfaceDeviation]? {
        var deviations: [SurfaceDeviation] = []

        // Extract template mesh
        guard let templateMesh = extractMesh(from: templateGeometry) else {
            return nil
        }

        // Build spatial index for fast nearest surface queries
        let spatialIndex = buildSpatialIndex(mesh: templateMesh)

        // Calculate deviation for each scanned point
        for point in points {
            let position = SIMD3<Float>(Float(point.x), Float(point.y), Float(point.z))

            // Find nearest surface point
            if let nearestSurface = findNearestSurfacePoint(
                position: position,
                spatialIndex: spatialIndex,
                mesh: templateMesh
            ) {
                // Calculate signed distance (positive = outside, negative = inside)
                let distance = distance(position, nearestSurface.point)
                let signedDistance = Double(distance * nearestSurface.normalSign)

                // Determine if within tolerance
                let withinTolerance = abs(signedDistance) <= 0.5 // ±0.5mm default tolerance

                // Generate heat map color
                let color = HeatMapColor.from(
                    deviation: signedDistance,
                    maxDeviation: maxDeviation
                )

                deviations.append(SurfaceDeviation(
                    point: point,
                    deviation: signedDistance,
                    withinTolerance: withinTolerance,
                    heatMapColor: color
                ))
            }
        }

        return deviations
    }

    /// Extract mesh from SCNNode
    private func extractMesh(from node: SCNNode) -> TemplateMesh? {
        var vertices: [SIMD3<Float>] = []
        var triangles: [(Int, Int, Int)] = []

        node.enumerateChildNodes { childNode, _ in
            guard let geometry = childNode.geometry,
                  let sources = geometry.sources(for: .vertex),
                  let elements = geometry.elements.first,
                  let vertexSource = sources.first else {
                return
            }

            // Extract vertices
            let vertexData = vertexSource.data
            let stride = vertexSource.dataStride
            let offset = vertexSource.dataOffset
            let count = vertexSource.vectorCount

            for i in 0..<count {
                let vertexOffset = offset + (i * stride)
                var vertex = SIMD3<Float>()
                vertexData.withUnsafeBytes { buffer in
                    let pointer = buffer.baseAddress!.advanced(by: vertexOffset)
                    vertex = pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                }
                vertices.append(vertex)
            }

            // Extract triangles
            let indexData = elements.data
            let indexCount = elements.primitiveCount * 3

            for i in stride(from: 0, to: indexCount, by: 3) {
                var indices = (0, 0, 0)
                indexData.withUnsafeBytes { buffer in
                    if elements.bytesPerIndex == 2 {
                        let pointer = buffer.baseAddress!.assumingMemoryBound(to: UInt16.self)
                        indices = (Int(pointer[i]), Int(pointer[i+1]), Int(pointer[i+2]))
                    } else {
                        let pointer = buffer.baseAddress!.assumingMemoryBound(to: UInt32.self)
                        indices = (Int(pointer[i]), Int(pointer[i+1]), Int(pointer[i+2]))
                    }
                }
                triangles.append(indices)
            }
        }

        return TemplateMesh(vertices: vertices, triangles: triangles)
    }

    /// Build spatial index for fast queries
    private func buildSpatialIndex(mesh: TemplateMesh) -> SpatialIndex {
        // Simple grid-based spatial index
        let gridSize: Float = 10.0 // mm
        var grid: [SIMD3<Int>: [Int]] = [:]

        for (index, vertex) in mesh.vertices.enumerated() {
            let gridCoord = SIMD3<Int>(
                Int(vertex.x / gridSize),
                Int(vertex.y / gridSize),
                Int(vertex.z / gridSize)
            )
            grid[gridCoord, default: []].append(index)
        }

        return SpatialIndex(grid: grid, gridSize: gridSize, mesh: mesh)
    }

    /// Find nearest surface point
    private func findNearestSurfacePoint(
        position: SIMD3<Float>,
        spatialIndex: SpatialIndex,
        mesh: TemplateMesh
    ) -> (point: SIMD3<Float>, normalSign: Float)? {
        let gridCoord = SIMD3<Int>(
            Int(position.x / spatialIndex.gridSize),
            Int(position.y / spatialIndex.gridSize),
            Int(position.z / spatialIndex.gridSize)
        )

        var nearestPoint = SIMD3<Float>()
        var minDistance = Float.infinity
        var normalSign: Float = 1.0

        // Search nearby grid cells
        for dx in -1...1 {
            for dy in -1...1 {
                for dz in -1...1 {
                    let searchCoord = SIMD3<Int>(
                        gridCoord.x + dx,
                        gridCoord.y + dy,
                        gridCoord.z + dz
                    )

                    guard let triangleIndices = spatialIndex.grid[searchCoord] else { continue }

                    for triangleIndex in triangleIndices {
                        let triangle = mesh.triangles[triangleIndex]
                        let v1 = mesh.vertices[triangle.0]
                        let v2 = mesh.vertices[triangle.1]
                        let v3 = mesh.vertices[triangle.2]

                        // Find closest point on triangle
                        let closestPoint = closestPointOnTriangle(
                            point: position,
                            v1: v1, v2: v2, v3: v3
                        )

                        let dist = distance(position, closestPoint)
                        if dist < minDistance {
                            minDistance = dist
                            nearestPoint = closestPoint

                            // Calculate normal sign
                            let normal = cross(v2 - v1, v3 - v1)
                            let toPoint = position - closestPoint
                            normalSign = dot(normalize(normal), normalize(toPoint)) > 0 ? 1.0 : -1.0
                        }
                    }
                }
            }
        }

        guard minDistance != Float.infinity else { return nil }
        return (nearestPoint, normalSign)
    }

    /// Find closest point on triangle
    private func closestPointOnTriangle(
        point: SIMD3<Float>,
        v1: SIMD3<Float>,
        v2: SIMD3<Float>,
        v3: SIMD3<Float>
    ) -> SIMD3<Float> {
        // Simplified - project point onto triangle plane
        let edge1 = v2 - v1
        let edge2 = v3 - v1
        let normal = normalize(cross(edge1, edge2))

        let toPoint = point - v1
        let distanceToPlane = dot(toPoint, normal)
        let projectedPoint = point - normal * distanceToPlane

        // Check if projected point is inside triangle
        let v1ToProjected = projectedPoint - v1
        let v2ToProjected = projectedPoint - v2
        let v3ToProjected = projectedPoint - v3

        let u = cross(edge1, v1ToProjected)
        let v = cross(v2ToProjected, v3 - v2)
        let w = cross(v3ToProjected, edge2)

        if dot(u, normal) >= 0 && dot(v, normal) >= 0 && dot(w, normal) >= 0 {
            return projectedPoint
        }

        // If outside, find closest edge point
        let edge3 = v1 - v3
        let closestOnEdge1 = closestPointOnSegment(point: projectedPoint, a: v1, b: v2)
        let closestOnEdge2 = closestPointOnSegment(point: projectedPoint, a: v2, b: v3)
        let closestOnEdge3 = closestPointOnSegment(point: projectedPoint, a: v3, b: v1)

        let dist1 = distance(projectedPoint, closestOnEdge1)
        let dist2 = distance(projectedPoint, closestOnEdge2)
        let dist3 = distance(projectedPoint, closestOnEdge3)

        if dist1 <= dist2 && dist1 <= dist3 {
            return closestOnEdge1
        } else if dist2 <= dist3 {
            return closestOnEdge2
        } else {
            return closestOnEdge3
        }
    }

    /// Find closest point on line segment
    private func closestPointOnSegment(
        point: SIMD3<Float>,
        a: SIMD3<Float>,
        b: SIMD3<Float>
    ) -> SIMD3<Float> {
        let ab = b - a
        let ap = point - a
        let t = clamp(dot(ap, ab) / dot(ab, ab), min: 0.0, max: 1.0)
        return a + ab * t
    }

    // MARK: - Deviation Map Generation

    /// Generate deviation map with tolerance evaluation
    private func generateDeviationMap(
        deviations: [SurfaceDeviation],
        tolerances: [Tolerance]
    ) -> DeviationMap {
        let deviationValues = deviations.map { abs($0.deviation) }

        return DeviationMap(
            deviations: deviations,
            maxDeviation: deviationValues.max() ?? 0.0,
            minDeviation: deviationValues.min() ?? 0.0,
            averageDeviation: deviationValues.reduce(0, +) / Double(deviationValues.count)
        )
    }

    // MARK: - Measurements

    /// Perform dimensional measurements
    private func performMeasurements(
        scannedData: ScannedPartData,
        template: Part,
        deviations: [SurfaceDeviation]
    ) -> [Measurement] {
        var measurements: [Measurement] = []

        // Measure against each tolerance specification
        for tolerance in template.metadata.tolerances {
            // Extract relevant points for this feature
            let featureDeviation = deviations.map { $0.deviation }.reduce(0, +) / Double(deviations.count)

            let measurement = Measurement(
                id: UUID(),
                feature: tolerance.feature,
                measuredValue: tolerance.nominalValue + featureDeviation,
                nominalValue: tolerance.nominalValue,
                deviation: featureDeviation,
                tolerance: tolerance,
                passed: abs(featureDeviation) <= (tolerance.upperLimit - tolerance.nominalValue)
            )

            measurements.append(measurement)
        }

        return measurements
    }

    // MARK: - Statistics

    /// Calculate inspection statistics
    private func calculateStatistics(
        deviations: [SurfaceDeviation],
        measurements: [Measurement],
        startTime: Date
    ) -> InspectionStatistics {
        let totalPoints = deviations.count
        let pointsInTolerance = deviations.filter { $0.withinTolerance }.count
        let pointsOutOfTolerance = totalPoints - pointsInTolerance
        let conformancePercentage = Double(pointsInTolerance) / Double(totalPoints) * 100.0
        let processingTime = Date().timeIntervalSince(startTime)

        return InspectionStatistics(
            totalPoints: totalPoints,
            pointsInTolerance: pointsInTolerance,
            pointsOutOfTolerance: pointsOutOfTolerance,
            conformancePercentage: conformancePercentage,
            processingTime: processingTime
        )
    }

    // MARK: - Status Determination

    /// Determine overall inspection status
    private func determineInspectionStatus(
        deviationMap: DeviationMap,
        measurements: [Measurement]
    ) -> InspectionStatus {
        let allPassed = measurements.allSatisfy { $0.passed }
        let criticalPassed = measurements
            .filter { $0.tolerance.criticalityLevel == .critical }
            .allSatisfy { $0.passed }

        if allPassed {
            return .passed
        } else if criticalPassed {
            return .conditional
        } else {
            return .failed
        }
    }
}

// MARK: - Supporting Types

struct TemplateMesh {
    let vertices: [SIMD3<Float>]
    let triangles: [(Int, Int, Int)]
}

struct SpatialIndex {
    let grid: [SIMD3<Int>: [Int]]
    let gridSize: Float
    let mesh: TemplateMesh
}

enum ComparisonError: Error, LocalizedError {
    case invalidGeometry
    case calculationFailed
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .invalidGeometry:
            return "Invalid template geometry"
        case .calculationFailed:
            return "Failed to calculate deviations"
        case .insufficientData:
            return "Insufficient data for comparison"
        }
    }
}
