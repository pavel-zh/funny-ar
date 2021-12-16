/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An `SCNNode` subclass demonstrating how to configure overlay content.
*/

import ARKit
import SceneKit

class GlassesOverlay: SCNNode, VirtualFaceContent {
    
    let occlusionNode: SCNNode
    
    private lazy var eyeLeftNode = childNode(withName: "eyeLeft", recursively: true)
    private lazy var eyeRightNode = childNode(withName: "eyeRight", recursively: true)
    
    /// - Tag: OcclusionMaterial
    init(geometry: ARSCNFaceGeometry) {

        /*
         Write depth but not color and render before other objects.
         This causes the geometry to occlude other SceneKit content
         while showing the camera view beneath, creating the illusion
         that real-world objects are obscuring virtual 3D objects.
         */
        geometry.firstMaterial!.colorBufferWriteMask = []
        occlusionNode = SCNNode(geometry: geometry)
        occlusionNode.renderingOrder = -1

        super.init()

        addChildNode(occlusionNode)
        
        // Add 3D content positioned as "glasses".
        let faceOverlayContent = loadedContentForAsset(named: "glassesModel")
        addChildNode(faceOverlayContent)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }
    
    /// - Tag: BlendShapeAnimation
    var blendShapes: [ARFaceAnchor.BlendShapeLocation: Any] = [:] {
        didSet {
            guard let eyeBlinkLeft = blendShapes[.eyeBlinkLeft] as? Float,
                let eyeBlinkRight = blendShapes[.eyeBlinkRight] as? Float
                else { return }
            eyeLeftNode?.scale.z = 0.7 - eyeBlinkLeft * 1.1
            eyeRightNode?.scale.z = 0.7 - eyeBlinkRight * 1.1
        }
    }
    
    // MARK: - VirtualFaceContent
    func update(withFaceAnchor faceAnchor: ARFaceAnchor) {
        blendShapes = faceAnchor.blendShapes
        
//        let faceGeometry = occlusionNode.geometry as! ARSCNFaceGeometry
//        faceGeometry.update(from: faceAnchor.geometry)
    }
}
