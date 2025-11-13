//
//  MainARViewController.swift
//  ARQualityInspection
//
//  Main AR inspection view controller
//  Copyright © 2025-2026 Institute of Energy Technology, HUST
//

import UIKit
import ARKit
import RealityKit
import Combine

/// Main view controller for AR quality inspection
class MainARViewController: UIViewController {

    // MARK: - Properties

    private var arView: ARView!
    private var controlPanel: UIView!
    private var statusLabel: UILabel!
    private var progressBar: UIProgressView!

    // Services
    private let scanningService = LiDARScanningService()
    private let recognitionEngine = ObjectRecognitionEngine()
    private let comparisonEngine = GeometricComparisonEngine()
    private let databaseManager = TemplateDatabaseManager()
    private var visualizationEngine: ARVisualizationEngine!

    // State
    private var currentState: InspectionState = .idle
    private var scannedData: ScannedPartData?
    private var recognizedPart: Part?
    private var inspectionResult: InspectionResult?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupARView()
        setupUI()
        setupServices()
        setupObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // AR session will be started by scanning service
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }

    // MARK: - Setup

    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)

        visualizationEngine = ARVisualizationEngine(arView: arView)
    }

    private func setupUI() {
        // Status label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.text = "Ready to scan"
        view.addSubview(statusLabel)

        // Progress bar
        progressBar = UIProgressView(progressViewStyle: .default)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progress = 0.0
        progressBar.isHidden = true
        view.addSubview(progressBar)

        // Control panel
        controlPanel = createControlPanel()
        view.addSubview(controlPanel)

        // Layout constraints
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 50),

            progressBar.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            controlPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            controlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            controlPanel.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func createControlPanel() -> UIView {
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        panel.layer.cornerRadius = 10

        // Scan button
        let scanButton = createButton(title: "Start Scan", action: #selector(startScanTapped))
        scanButton.tag = 1

        // Recognize button
        let recognizeButton = createButton(title: "Recognize", action: #selector(recognizeTapped))
        recognizeButton.tag = 2
        recognizeButton.isEnabled = false

        // Compare button
        let compareButton = createButton(title: "Compare", action: #selector(compareTapped))
        compareButton.tag = 3
        compareButton.isEnabled = false

        // Results button
        let resultsButton = createButton(title: "Results", action: #selector(showResultsTapped))
        resultsButton.tag = 4
        resultsButton.isEnabled = false

        // Stack view
        let stackView = UIStackView(arrangedSubviews: [scanButton, recognizeButton, compareButton, resultsButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        panel.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -10)
        ])

        return panel
    }

    private func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func setupServices() {
        // Services are already initialized
    }

    private func setupObservers() {
        // Observe scan progress
        scanningService.$currentPointCount
            .sink { [weak self] count in
                DispatchQueue.main.async {
                    self?.statusLabel.text = "Scanning... \(count) points captured"
                }
            }
            .store(in: &cancellables)

        scanningService.$scanQuality
            .sink { [weak self] quality in
                DispatchQueue.main.async {
                    self?.progressBar.progress = Float(quality)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func startScanTapped(_ sender: UIButton) {
        switch currentState {
        case .idle, .completed:
            startScanning()
        case .scanning:
            stopScanning()
        default:
            break
        }
    }

    @objc private func recognizeTapped() {
        guard let scannedData = scannedData else { return }

        updateState(.recognizing)
        statusLabel.text = "Recognizing part..."

        let templates = databaseManager.getAllTemplates()

        recognitionEngine.recognizePart(scannedData: scannedData, from: templates) { [weak self] result in
            switch result {
            case .success(let recognitionResult):
                self?.recognizedPart = recognitionResult.recognizedPart
                self?.updateState(.recognized)

                self?.statusLabel.text = """
                Recognized: \(recognitionResult.recognizedPart.name)
                Confidence: \(Int(recognitionResult.confidence * 100))%
                """

                self?.enableButton(tag: 3)

            case .failure(let error):
                self?.showError(error.localizedDescription)
                self?.updateState(.idle)
            }
        }
    }

    @objc private func compareTapped() {
        guard let scannedData = scannedData,
              let recognizedPart = recognizedPart else { return }

        updateState(.comparing)
        statusLabel.text = "Comparing with template..."

        // Load template geometry
        guard let templateGeometry = databaseManager.loadGeometry(for: recognizedPart) else {
            showError("Failed to load template geometry")
            return
        }

        // Use pose from recognition (simplified - in reality would come from recognition result)
        let pose = Pose(
            translation: SIMD3<Double>(0, 0, 0),
            rotation: simd_quatd(angle: 0, axis: SIMD3<Double>(0, 1, 0))
        )

        comparisonEngine.compare(
            scannedData: scannedData,
            template: recognizedPart,
            templateGeometry: templateGeometry,
            pose: pose
        ) { [weak self] result in
            switch result {
            case .success(let inspectionResult):
                self?.inspectionResult = inspectionResult
                self?.updateState(.visualizing)

                // Render heat map
                self?.visualizationEngine.renderHeatMap(
                    deviationMap: inspectionResult.deviationMap,
                    pose: pose,
                    meshData: scannedData.meshData
                ) { success in
                    if success {
                        self?.statusLabel.text = """
                        Status: \(inspectionResult.overallStatus.rawValue.capitalized)
                        Conformance: \(String(format: "%.1f%%", inspectionResult.statistics.conformancePercentage))
                        """

                        self?.enableButton(tag: 4)
                        self?.updateState(.completed)
                    } else {
                        self?.showError("Failed to render visualization")
                    }
                }

            case .failure(let error):
                self?.showError(error.localizedDescription)
                self?.updateState(.recognized)
            }
        }
    }

    @objc private func showResultsTapped() {
        guard let inspectionResult = inspectionResult else { return }

        let resultsVC = InspectionResultsViewController(result: inspectionResult)
        resultsVC.modalPresentationStyle = .pageSheet

        if let sheet = resultsVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        present(resultsVC, animated: true)
    }

    // MARK: - Scanning

    private func startScanning() {
        progressBar.isHidden = false
        progressBar.progress = 0.0

        scanningService.startScanning { [weak self] result in
            switch result {
            case .success:
                self?.updateState(.scanning)
                self?.statusLabel.text = "Scanning..."

                if let button = self?.controlPanel.viewWithTag(1) as? UIButton {
                    button.setTitle("Stop Scan", for: .normal)
                    button.backgroundColor = .systemRed
                }

            case .failure(let error):
                self?.showError(error.localizedDescription)
            }
        }
    }

    private func stopScanning() {
        guard let data = scanningService.stopScanning() else {
            showError("Insufficient scan data")
            return
        }

        scannedData = data
        updateState(.scanned)

        statusLabel.text = "Scan complete: \(data.pointCloud.count) points"
        progressBar.isHidden = true

        if let button = controlPanel.viewWithTag(1) as? UIButton {
            button.setTitle("Start Scan", for: .normal)
            button.backgroundColor = .systemBlue
        }

        enableButton(tag: 2)
    }

    // MARK: - State Management

    private func updateState(_ newState: InspectionState) {
        currentState = newState
    }

    private func enableButton(tag: Int) {
        if let button = controlPanel.viewWithTag(tag) as? UIButton {
            button.isEnabled = true
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Inspection State

enum InspectionState {
    case idle
    case scanning
    case scanned
    case recognizing
    case recognized
    case comparing
    case visualizing
    case completed
}

// MARK: - Results View Controller

class InspectionResultsViewController: UIViewController {

    private let result: InspectionResult
    private var tableView: UITableView!

    init(result: InspectionResult) {
        self.result = result
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Inspection Results"

        setupTableView()
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
    }
}

extension InspectionResultsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 4 // Summary
        case 1: return result.measurements.count // Measurements
        case 2: return 4 // Statistics
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Summary"
        case 1: return "Measurements"
        case 2: return "Statistics"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        switch indexPath.section {
        case 0: // Summary
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Status: \(result.overallStatus.rawValue.capitalized)"
            case 1:
                cell.textLabel?.text = "Date: \(formatDate(result.inspectionDate))"
            case 2:
                cell.textLabel?.text = "Max Deviation: \(String(format: "%.3f mm", result.deviationMap.maxDeviation))"
            case 3:
                cell.textLabel?.text = "Avg Deviation: \(String(format: "%.3f mm", result.deviationMap.averageDeviation))"
            default:
                break
            }

        case 1: // Measurements
            let measurement = result.measurements[indexPath.row]
            cell.textLabel?.text = "\(measurement.feature): \(String(format: "%.2f mm", measurement.deviation))"
            cell.accessoryType = measurement.passed ? .checkmark : .none
            cell.textLabel?.textColor = measurement.passed ? .systemGreen : .systemRed

        case 2: // Statistics
            let stats = result.statistics
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Total Points: \(stats.totalPoints)"
            case 1:
                cell.textLabel?.text = "In Tolerance: \(stats.pointsInTolerance)"
            case 2:
                cell.textLabel?.text = "Conformance: \(String(format: "%.1f%%", stats.conformancePercentage))"
            case 3:
                cell.textLabel?.text = "Processing Time: \(String(format: "%.2fs", stats.processingTime))"
            default:
                break
            }

        default:
            break
        }

        return cell
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
