//
//  LiDARScanningService.swift
//  ARQualityInspection
//
//  LiDAR scanning service using ARKit
//  Copyright © 2025-2026 Institute of Energy Technology, HUST
//

import Foundation
import ARKit
import RealityKit
import Combine

/// Service for LiDAR-based 3D scanning
class LiDARScanningService: NSObject {

    // MARK: - Properties

    private var arSession: ARSession
    private var sceneReconstructor: ARSceneReconstruction?
    private var pointCloudData: [Point3D] = []
    private var meshAnchors: [ARMeshAnchor] = []

    private let processingQueue = DispatchQueue(label: "com.hwashin.lidar.processing")

    var isScanning: Bool = false
    var scanProgress: Double = 0.0

    // Publishers for reactive updates
    @Published var currentPointCount: Int = 0
    @Published var scanQuality: Double = 0.0

    // MARK: - Initialization

    override init() {
        self.arSession = ARSession()
        super.init()
        self.arSession.delegate = self
    }

    // MARK: - Scanning Control

    /// Start LiDAR scanning session
    func startScanning(completion: @escaping (Result<Void, ScanError>) -> Void) {
        // Check LiDAR availability
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            completion(.failure(.lidarNotSupported))
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.environmentTexturing = .automatic
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]

        // Enable plane detection for better alignment
        configuration.planeDetection = [.horizontal, .vertical]

        // Start session
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        isScanning = true
        pointCloudData.removeAll()
        meshAnchors.removeAll()

        completion(.success(()))
    }

    /// Stop scanning and process data
    func stopScanning() -> ScannedPartData? {
        isScanning = false
        arSession.pause()

        guard !pointCloudData.isEmpty else {
            return nil
        }

        let meshData = reconstructMesh(from: meshAnchors)

        return ScannedPartData(
            pointCloud: pointCloudData,
            meshData: meshData,
            scanDate: Date(),
            scanQuality: scanQuality,
            deviceInfo: getDeviceInfo()
        )
    }

    /// Pause scanning temporarily
    func pauseScanning() {
        isScanning = false
    }

    /// Resume scanning
    func resumeScanning() {
        isScanning = true
    }

    // MARK: - Data Processing

    /// Extract point cloud from AR frame
    private func extractPointCloud(from frame: ARFrame) {
        guard let depthMap = frame.sceneDepth?.depthMap else { return }

        let depthData = CIImage(cvPixelBuffer: depthMap)
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let buffer = baseAddress.assumingMemoryBound(to: Float32.self)

        // Sample points (every 5th pixel for performance)
        let step = 5
        var newPoints: [Point3D] = []

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let index = y * width + x
                let depth = buffer[index]

                // Skip invalid depth values
                guard depth > 0 && depth < 10.0 else { continue }

                // Convert 2D pixel + depth to 3D point
                let normalizedX = Float(x) / Float(width)
                let normalizedY = Float(y) / Float(height)

                let ray = frame.camera.unprojectPoint(
                    SIMD3<Float>(normalizedX, normalizedY, 1.0),
                    ontoPlaneAt: depth
                )

                let confidence = getDepthConfidence(depth: depth)

                newPoints.append(Point3D(
                    x: Double(ray.x),
                    y: Double(ray.y),
                    z: Double(ray.z),
                    confidence: confidence
                ))
            }
        }

        processingQueue.async { [weak self] in
            self?.pointCloudData.append(contentsOf: newPoints)
            DispatchQueue.main.async {
                self?.currentPointCount = self?.pointCloudData.count ?? 0
            }
        }
    }

    /// Reconstruct mesh from mesh anchors
    private func reconstructMesh(from anchors: [ARMeshAnchor]) -> MeshData {
        var allVertices: [Point3D] = []
        var allNormals: [Point3D] = []
        var allTriangles: [Int] = []
        var vertexOffset = 0

        for anchor in anchors {
            let geometry = anchor.geometry

            // Extract vertices
            let vertices = geometry.vertices
            for i in 0..<vertices.count {
                let vertex = vertices[i]
                let worldPosition = anchor.transform * SIMD4<Float>(vertex.0, vertex.1, vertex.2, 1.0)
                allVertices.append(Point3D(
                    x: Double(worldPosition.x),
                    y: Double(worldPosition.y),
                    z: Double(worldPosition.z),
                    confidence: 1.0
                ))
            }

            // Extract normals
            let normals = geometry.normals
            for i in 0..<normals.count {
                let normal = normals[i]
                allNormals.append(Point3D(
                    x: Double(normal.0),
                    y: Double(normal.1),
                    z: Double(normal.2),
                    confidence: 1.0
                ))
            }

            // Extract triangles (faces)
            let faces = geometry.faces
            let indexBuffer = faces.buffer
            for i in 0..<faces.count {
                let index = i * 3
                let i1 = indexBuffer[index] + vertexOffset
                let i2 = indexBuffer[index + 1] + vertexOffset
                let i3 = indexBuffer[index + 2] + vertexOffset
                allTriangles.append(contentsOf: [i1, i2, i3])
            }

            vertexOffset += vertices.count
        }

        return MeshData(
            vertices: allVertices,
            normals: allNormals,
            triangles: allTriangles
        )
    }

    /// Calculate depth confidence
    private func getDepthConfidence(depth: Float) -> Float {
        // Confidence decreases with distance
        if depth < 1.0 {
            return 0.95
        } else if depth < 3.0 {
            return 0.85
        } else if depth < 5.0 {
            return 0.70
        } else {
            return 0.50
        }
    }

    /// Get device information
    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            lidarCapable: ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh),
            scanResolution: "High"
        )
    }

    /// Calculate scan quality based on point density and coverage
    private func calculateScanQuality() -> Double {
        guard !pointCloudData.isEmpty else { return 0.0 }

        // Quality factors:
        // 1. Point cloud density
        // 2. Mesh anchor coverage
        // 3. Tracking quality

        let pointDensityScore = min(Double(pointCloudData.count) / 100000.0, 1.0)
        let meshCoverageScore = min(Double(meshAnchors.count) / 50.0, 1.0)

        return (pointDensityScore * 0.6 + meshCoverageScore * 0.4)
    }
}

// MARK: - ARSessionDelegate

extension LiDARScanningService: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isScanning else { return }

        // Extract point cloud from frame
        extractPointCloud(from: frame)

        // Update scan quality
        scanQuality = calculateScanQuality()
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
                    meshAnchors[index] = meshAnchor
                }
            }
        }
    }
}

// MARK: - Error Types

enum ScanError: Error, LocalizedError {
    case lidarNotSupported
    case sessionFailed
    case insufficientData
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .lidarNotSupported:
            return "LiDAR scanner is not available on this device"
        case .sessionFailed:
            return "AR session failed to start"
        case .insufficientData:
            return "Insufficient scan data collected"
        case .processingFailed:
            return "Failed to process scan data"
        }
    }
}
