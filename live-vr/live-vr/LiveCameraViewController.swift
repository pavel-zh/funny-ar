//
//  LiveCameraViewController.swift
//  live-vr
//
//  Created by Pavel Zhuravlev on 12/15/21.
//

import UIKit
import AVFoundation
import ARKit
import SceneKit

class LiveCameraViewController: UIViewController {

    @IBOutlet private var mySceneView: UIView!
    var sceneView: ARSCNView? {
        return mySceneView as? ARSCNView
    }
    var arSession: ARSession? {
        return sceneView?.session
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
//        videoPreviewView.cr_fillContainerWithInsets(.zero)
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

    func createFaceGeometry() {
        // This relies on the earlier check of `ARFaceTrackingConfiguration.isSupported`.
        guard let device = sceneView?.device else {
            return
        }
        
        let maskGeometry = ARSCNFaceGeometry(device: device)!
        let glassesGeometry = ARSCNFaceGeometry(device: device)!
        
        nodeForContentType = [
            .faceGeometry: Mask(geometry: maskGeometry),
            .overlayModel: GlassesOverlay(geometry: glassesGeometry),
            .blendShapeModel: RobotHead(geometry: maskGeometry),
            .noseModel: NoseOverlay(geometry: glassesGeometry),
            .earsModel: EarsOverlay(geometry: glassesGeometry),
            .glassesModel: GlassesOverlay(geometry: glassesGeometry)
        ]
    }

    private func setupCamera(onBack backCameraSelected: Bool,
                             with completion: @escaping ((_ camera: AVCaptureDevice, _ cameraSettings: AVCaptureDevice.DiscoverySession) -> Void)) {
        
        session.stopRunning()
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
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
//                self.cameraSwitchButton.isHidden = deviceDescoverySession.devices.count <= 1
//                self.flashButton.isHidden = !camera.hasFlash
//                self.shutterButton.isHidden = false

                completion(camera, deviceDescoverySession)
            }
        }
    }

}

extension LiveCameraViewController: ARSessionDelegate {
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
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.resetTracking()
        }
    }
    
    /// - Tag: ARFaceTrackingSetup
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Interface Actions
    
    /// - Tag: restartExperience
    func restartExperience() {
        // Disable Restart button for a while in order to give the session enough time to restart.
//        statusViewController.isRestartExperienceButtonEnabled = false
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
//            self.statusViewController.isRestartExperienceButtonEnabled = true
//        }
        
        resetTracking()
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}
