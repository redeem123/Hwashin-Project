//
//  ARVisualizationEngine.swift
//  ARQualityInspection
//
//  AR visualization engine for heat map overlay
//  Copyright © 2025-2026 Institute of Energy Technology, HUST
//

import Foundation
import ARKit
import RealityKit
import SceneKit

/// Engine for rendering AR heat map overlays
class ARVisualizationEngine {

    // MARK: - Properties

    private var arView: ARView?
    private var overlayEntity: ModelEntity?
    private var heatMapMaterial: PhysicallyBasedMaterial?

    // Visualization settings
    var opacity: Float = 0.8
    var showWireframe: Bool = false
    var animateTransition: Bool = true

    // MARK: - Initialization

    init(arView: ARView) {
        self.arView = arView
        setupARView()
    }

    // MARK: - AR View Setup

    private func setupARView() {
        guard let arView = arView else { return }

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        arView.session.run(configuration)

        // Configure rendering
        arView.renderOptions = [.disableMotionBlur]
        arView.environment.sceneUnderstanding.options = [.occlusion, .receivesLighting]
    }

    // MARK: - Visualization

    /// Render heat map overlay on AR view
    func renderHeatMap(
        deviationMap: DeviationMap,
        pose: Pose,
        meshData: MeshData,
        completion: @escaping (Bool) -> Void
    ) {
        guard let arView = arView else {
            completion(false)
            return
        }

        DispatchQueue.main.async {
            // Remove existing overlay
            self.removeOverlay()

            // Create mesh from deviation map
            guard let mesh = self.createColoredMesh(
                deviationMap: deviationMap,
                meshData: meshData
            ) else {
                completion(false)
                return
            }

            // Create material with heat map colors
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: .white.withAlphaComponent(CGFloat(self.opacity)))
            material.roughness = 0.5
            material.metallic = 0.0

            // Create model entity
            let modelEntity = ModelEntity(mesh: mesh, materials: [material])

            // Apply pose transformation
            let transform = self.createTransform(from: pose)
            modelEntity.transform = transform

            // Add to AR scene
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(modelEntity)
            arView.scene.addAnchor(anchor)

            // Animate if enabled
            if self.animateTransition {
                modelEntity.scale = SIMD3<Float>(0.01, 0.01, 0.01)
                modelEntity.move(
                    to: transform,
                    relativeTo: anchor,
                    duration: 0.5,
                    timingFunction: .easeOut
                )
            }

            self.overlayEntity = modelEntity
            completion(true)
        }
    }

    /// Create colored mesh from deviation map
    private func createColoredMesh(
        deviationMap: DeviationMap,
        meshData: MeshData
    ) -> MeshResource? {
        var meshDescriptor = MeshDescriptor()

        // Convert vertices
        var positions: [SIMD3<Float>] = []
        for vertex in meshData.vertices {
            positions.append(SIMD3<Float>(
                Float(vertex.x),
                Float(vertex.y),
                Float(vertex.z)
            ))
        }
        meshDescriptor.positions = MeshBuffer(positions)

        // Convert normals
        var normals: [SIMD3<Float>] = []
        for normal in meshData.normals {
            normals.append(SIMD3<Float>(
                Float(normal.x),
                Float(normal.y),
                Float(normal.z)
            ))
        }
        meshDescriptor.normals = MeshBuffer(normals)

        // Generate vertex colors based on heat map
        var colors: [UInt32] = []
        for deviation in deviationMap.deviations {
            let color = deviation.heatMapColor
            let r = UInt32(color.red * 255)
            let g = UInt32(color.green * 255)
            let b = UInt32(color.blue * 255)
            let a = UInt32(color.alpha * 255)

            // Pack RGBA into UInt32
            let packedColor = (a << 24) | (b << 16) | (g << 8) | r
            colors.append(packedColor)
        }
        meshDescriptor.colors = MeshBuffer(colors)

        // Convert triangle indices
        var indices: [UInt32] = []
        for index in meshData.triangles {
            indices.append(UInt32(index))
        }
        meshDescriptor.primitives = .triangles(indices)

        // Create mesh resource
        return try? MeshResource.generate(from: [meshDescriptor])
    }

    /// Create transform matrix from pose
    private func createTransform(from pose: Pose) -> Transform {
        let translation = SIMD3<Float>(
            Float(pose.translation.x),
            Float(pose.translation.y),
            Float(pose.translation.z)
        )

        let rotation = simd_quatf(
            ix: Float(pose.rotation.imag.x),
            iy: Float(pose.rotation.imag.y),
            iz: Float(pose.rotation.imag.z),
            r: Float(pose.rotation.real)
        )

        return Transform(
            scale: SIMD3<Float>(1, 1, 1),
            rotation: rotation,
            translation: translation
        )
    }

    /// Remove current overlay
    func removeOverlay() {
        overlayEntity?.removeFromParent()
        overlayEntity = nil
    }

    // MARK: - Interactive Visualization

    /// Highlight specific region
    func highlightRegion(deviations: [SurfaceDeviation]) {
        // Implementation for highlighting specific regions
        // This could be used to focus on areas with high deviation
    }

    /// Show measurement annotations
    func showMeasurements(_ measurements: [Measurement], at points: [SIMD3<Float>]) {
        guard let arView = arView else { return }

        for (index, measurement) in measurements.enumerated() {
            guard index < points.count else { break }

            // Create text annotation
            let text = String(format: "%.2f mm", measurement.deviation)
            let textEntity = createTextEntity(text: text, color: measurement.passed ? .green : .red)

            // Position at measurement point
            textEntity.position = points[index]

            // Add to scene
            let anchor = AnchorEntity(world: points[index])
            anchor.addChild(textEntity)
            arView.scene.addAnchor(anchor)
        }
    }

    /// Create text entity for annotations
    private func createTextEntity(text: String, color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.05),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        var material = UnlitMaterial()
        material.color = .init(tint: color)

        return ModelEntity(mesh: mesh, materials: [material])
    }

    // MARK: - Screenshot and Recording

    /// Capture screenshot of current AR view
    func captureScreenshot() -> UIImage? {
        guard let arView = arView else { return nil }

        let renderer = UIGraphicsImageRenderer(size: arView.bounds.size)
        return renderer.image { context in
            arView.drawHierarchy(in: arView.bounds, afterScreenUpdates: true)
        }
    }

    /// Start recording AR session
    func startRecording(completion: @escaping (Result<URL, RecordingError>) -> Void) {
        // Implementation for video recording
        // This would use AVFoundation to record the AR view
        completion(.failure(.notImplemented))
    }

    // MARK: - Visualization Modes

    enum VisualizationMode {
        case heatMap
        case wireframe
        case points
        case hybrid
    }

    /// Switch visualization mode
    func setVisualizationMode(_ mode: VisualizationMode) {
        switch mode {
        case .heatMap:
            showWireframe = false
        case .wireframe:
            showWireframe = true
        case .points:
            // Show point cloud visualization
            break
        case .hybrid:
            // Show combined visualization
            break
        }
    }

    // MARK: - Color Legend

    /// Generate color legend for heat map
    func generateColorLegend(maxDeviation: Double) -> [(color: UIColor, label: String)] {
        var legend: [(UIColor, String)] = []

        let steps = 5
        for i in 0...steps {
            let deviation = (Double(i) / Double(steps)) * maxDeviation
            let heatMapColor = HeatMapColor.from(deviation: deviation, maxDeviation: maxDeviation)

            let color = UIColor(
                red: CGFloat(heatMapColor.red),
                green: CGFloat(heatMapColor.green),
                blue: CGFloat(heatMapColor.blue),
                alpha: CGFloat(heatMapColor.alpha)
            )

            let label = String(format: "%.2f mm", deviation)
            legend.append((color, label))
        }

        return legend
    }
}

// MARK: - Recording Error

enum RecordingError: Error, LocalizedError {
    case notImplemented
    case recordingFailed(Error)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Recording feature not yet implemented"
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        case .permissionDenied:
            return "Camera/microphone permission denied"
        }
    }
}
