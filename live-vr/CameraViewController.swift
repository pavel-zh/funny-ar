//
//  CameraViewController.swift
//  live-vr
//
//  Created by Pavel Zhuravlev on 12/15/21.
//

import UIKit
import AVFoundation
import ARKit
import SceneKit

class CameraViewController: UIViewController {

    @IBOutlet private var cameraSwitchButton: UIButton!
    @IBOutlet private var cameraButtons: [UIButton]!
    
    @IBOutlet private var mySceneView: UIView!
    var sceneView: ARSCNView? {
        mySceneView as? ARSCNView
    }
    var arSession: ARSession? {
        sceneView?.session
    }
    var nodeForContentType = [VirtualContentType: VirtualFaceNode]()
    let contentUpdater = VirtualContentUpdater()
    var selectedVirtualContent: VirtualContentType = .overlayModel {
        didSet {
            // Set the selected content based on the content type.
            contentUpdater.virtualFaceNode = nodeForContentType[selectedVirtualContent]
        }
    }
    
    private let session = AVCaptureSession()
    private var stillImageOutput: AVCapturePhotoOutput?
    private var deviceInput: AVCaptureInput?
    var videoPreviewView: UIView?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var camera: AVCaptureDevice?

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView?.delegate = contentUpdater
        sceneView?.session.delegate = self
        sceneView?.automaticallyUpdatesLighting = true
        createFaceGeometry()

        let videoPreviewView = UIView()
        videoPreviewView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(videoPreviewView, at: 0)
        videoPreviewView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        videoPreviewView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        videoPreviewView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        videoPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        self.videoPreviewView = videoPreviewView
        DispatchQueue.global().async {
            self.setupCamera(onBack: false) { _, _ in
                self.videoPreviewLayer?.removeFromSuperlayer()
                let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                videoPreviewLayer.videoGravity = .resizeAspectFill
                videoPreviewLayer.connection?.videoOrientation = .portrait
                videoPreviewView.layer.addSublayer(videoPreviewLayer)
                videoPreviewView.layoutIfNeeded()
                videoPreviewLayer.frame = videoPreviewView.bounds
                self.videoPreviewLayer = videoPreviewLayer
                self.session.startRunning()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // TODO: do this when arScene view shows
        resetTracking()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // TODO: do when arView hides
        arSession?.pause()
    }

    @IBAction func switchCameraAction(switchCameraButton: UIButton) {
        guard let videoPreviewView = videoPreviewView,
              let cameraSnapshot = videoPreviewView.snapshotView(afterScreenUpdates: true)
        else {
            return
        }
        
        switchCameraButton.isSelected = !switchCameraButton.isSelected
        view.insertSubview(cameraSnapshot, aboveSubview: videoPreviewView)
        setupCamera(onBack: !switchCameraButton.isSelected) { [weak self] _, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.videoPreviewLayer?.removeFromSuperlayer()
            let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: strongSelf.session)
            videoPreviewLayer.videoGravity = .resizeAspectFill
            videoPreviewLayer.connection?.videoOrientation = .portrait
            videoPreviewView.layer.addSublayer(videoPreviewLayer)
            videoPreviewLayer.frame = videoPreviewView.bounds
            strongSelf.videoPreviewLayer = videoPreviewLayer
            strongSelf.session.startRunning()
            strongSelf.resetTracking()
            UIView.transition(
                from: cameraSnapshot,
                to: videoPreviewView,
                duration: 0.4,
                options: !switchCameraButton.isSelected ? .transitionFlipFromLeft : .transitionFlipFromRight,
                completion: { [weak self] _ in
                    cameraSnapshot.removeFromSuperview()
                    self?.cameraButtons.forEach { self?.view.bringSubviewToFront($0) }
                })
        }
    }

    @IBAction func noseAction(button: UIButton) {
        button.isSelected = !button.isSelected
        selectedVirtualContent = button.isSelected ? .noseModel : .none
    }
    
    @IBAction func earsAction(button: UIButton) {
        button.isSelected = !button.isSelected
        selectedVirtualContent = button.isSelected ? .earsModel : .none
    }
    
    @IBAction func glassesAction(button: UIButton) {
        button.isSelected = !button.isSelected
        selectedVirtualContent = button.isSelected ? .glassesModel : .none
    }

    private func setupCamera(onBack backCameraSelected: Bool,
                             with completion: @escaping ((_ camera: AVCaptureDevice, _ cameraSettings: AVCaptureDevice.DiscoverySession) -> Void)) {
        session.stopRunning()
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified)
        
        session.sessionPreset = .high
        
        if backCameraSelected && deviceDescoverySession.devices.count > 1 {
            camera = deviceDescoverySession.devices[1]
        }
        else {
            camera = .default(for: .video)
        }
        
        guard let camera = camera else {
            return
        }
        
        if let deviceInput = deviceInput {
            session.removeInput(deviceInput)
        }
        
        deviceInput = try? AVCaptureDeviceInput(device: camera)
        guard let deviceInput = deviceInput else {
            return
        }
        
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }

        if let stillImageOutput = stillImageOutput {
            session.removeOutput(stillImageOutput)
        }

        stillImageOutput = AVCapturePhotoOutput()
        guard let stillImageOutput = stillImageOutput else {
            return
        }
        
        if session.canAddOutput(stillImageOutput) {
            session.addOutput(stillImageOutput)
            
            DispatchQueue.main.async {
                completion(camera, deviceDescoverySession)
            }
        }
    }
    
    func refreshVirtualContent() {
        // TODO:
//        contentUpdater.virtualFaceNode = nodeForContentType[selectedVirtualContent]
    }
    
    func createFaceGeometry() {
        // This relies on the earlier check of `ARFaceTrackingConfiguration.isSupported`.
        guard let device = sceneView?.device,
              let faceGeometry = ARSCNFaceGeometry(device: device)
        else {
            return
        }
        nodeForContentType = [
            .faceGeometry: Mask(geometry: faceGeometry),
            .overlayModel: GlassesOverlay(geometry: faceGeometry),
            .blendShapeModel: RobotHead(geometry: faceGeometry),
            .noseModel: NoseOverlay(geometry: faceGeometry),
            .earsModel: EarsOverlay(geometry: faceGeometry),
            .glassesModel: GlassesOverlay(geometry: faceGeometry)
        ]
    }
}

extension CameraViewController: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.resetTracking()
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.resetTracking()
        }
    }
    
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        cameraButtons.filter {
            $0 != cameraSwitchButton
        }
        .forEach {
            $0.isSelected = false
        }
    }
    
    // MARK: - Error handling
    func displayErrorMessage(title: String, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { [unowned self] _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}
