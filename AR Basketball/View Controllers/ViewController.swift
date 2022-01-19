//
//  ViewController.swift
//  AR-Basketball
//
//  Created by Евгений Пашко
//

import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    // MARK: - @IBOutlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    
    
    // MARK: - Properties
    let configuration = ARWorldTrackingConfiguration()
    
    private var isHoopAdded = false {
        didSet {
            configuration.planeDetection = self.isHoopAdded ? [] : [.horizontal, .vertical]
            configuration.isLightEstimationEnabled = true
            sceneView.session.run(configuration, options: .removeExistingAnchors)
        }
    }
    
    var score: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.scoreLabel.text = "Счёт: \(self.score)"
            }
        }
    }
    
    var isBallBeginContactWithRim = false
    var isBallEndContactWithRim = true
    
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Detect vertical planes
        configuration.planeDetection = [.horizontal, .vertical]
        
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    // MARK: - Private Methods
    private func updateUI() {
        // Set padding to stackview
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.isHidden = true
    }
    
    private func getBallNode() -> SCNNode? {
        // Get current position to the ball
        guard let frame = sceneView.session.currentFrame else {
            return nil
        }
        
        // Get camera transform
        let cameraTransform = frame.camera.transform
        let matrixCameraTransform = SCNMatrix4(cameraTransform)
        
        // Ball geometry and color
        let ball = SCNSphere(radius: 0.125)
        let ballTexture: UIImage = #imageLiteral(resourceName: "basketball")
        ball.firstMaterial?.diffuse.contents = ballTexture
        
        // Ball node
        let ballNode = SCNNode(geometry: ball)
        ballNode.name = "ball"
        
        // Calculate force matrix for pushing the ball
        let power = Float(5)
        let x = -matrixCameraTransform.m31 * power
        let y = -matrixCameraTransform.m32 * power
        let z = -matrixCameraTransform.m33 * power
        let forceDirection = SCNVector3(x, y, z)
        
        // Add physics
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ballNode))
        
        ballNode.physicsBody?.mass = 0.570
        
        // Apply force
        ballNode.physicsBody?.applyForce(forceDirection, asImpulse: true)
        
        // Set parameters for ball to react with hoop and count score points
        
        ballNode.physicsBody?.categoryBitMask = BodyType.ball.rawValue
        ballNode.physicsBody?.collisionBitMask = BodyType.ball.rawValue | BodyType.board.rawValue | BodyType.rim.rawValue
        ballNode.physicsBody?.contactTestBitMask = BodyType.topPlane.rawValue | BodyType.bottomPlane.rawValue
        
        // Assign camera position to ball
        ballNode.simdTransform = cameraTransform
        
        return ballNode
    }
    
    private func getHoopNode() -> SCNNode {
        let scene = SCNScene(named: "Hoop.scn", inDirectory: "art.scnassets")!
        let hoopNode = SCNNode()
        let board = scene.rootNode.childNode(withName: "board", recursively: false)!.clone()
        let rim = scene.rootNode.childNode(withName: "rim", recursively: false)!.clone()
        let topPlane = scene.rootNode.childNode(withName: "top plane", recursively: false)!.clone()
        let bottomPlane = scene.rootNode.childNode(withName: "bottom plane", recursively: false)!.clone()
        
        board.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: board,
                options: [
                    SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron
                ]
            )
        )
 
        board.physicsBody?.categoryBitMask = BodyType.board.rawValue
        
        rim.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: rim,
                options: [
                    SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron
                ]
            )
        )
        
        rim.physicsBody?.categoryBitMask = BodyType.rim.rawValue
        
        topPlane.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: topPlane,
                options: [
                    SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron
                ]
            )
        )
        
        topPlane.physicsBody?.categoryBitMask = BodyType.topPlane.rawValue
        topPlane.physicsBody?.collisionBitMask = BodyType.ball.rawValue
        topPlane.opacity = 0
        
        bottomPlane.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: bottomPlane,
                options: [
                    SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron
                ]
            )
        )
        
        bottomPlane.physicsBody?.categoryBitMask = BodyType.bottomPlane.rawValue
        bottomPlane.physicsBody?.collisionBitMask = BodyType.ball.rawValue
        bottomPlane.opacity = 0
        
        hoopNode.addChildNode(board)
        hoopNode.addChildNode(rim)
        hoopNode.addChildNode(topPlane)
        hoopNode.addChildNode(bottomPlane)
        
        return hoopNode.clone()
    }
    
    private func getPlaneNode(for plane: ARPlaneAnchor) -> SCNNode {
        let extent = plane.extent
        
        let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.blue
        
        // Create 75% transparent plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.25
        
        // Rotate plane
        planeNode.eulerAngles.x -= .pi / 2
        
        return planeNode
    }
    
    private func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
            return
        }
        
        // Change plane node center
        planeNode.simdPosition = anchor.center
        
        // Change plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        
    }
    
    private func removeFromScene(_ node: SCNNode, fallLengh: Float) {
        if node.presentation.position.y < fallLengh {
            node.removeFromParentNode()
        }
    }
    
    private func restartGame() {
        isHoopAdded = false
        score = 0
        isBallBeginContactWithRim = false
        isBallEndContactWithRim = true

        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            if node.name != nil {
                node.removeFromParentNode()
            }
        }
        
        stackView.isHidden = true
    }
    
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Add hoop to the center of vertical plane
        node.addChildNode(getPlaneNode(for: planeAnchor))
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Update plane node
        updatePlaneNode(node, for: planeAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.physicsBody?.categoryBitMask == BodyType.ball.rawValue {
                removeFromScene(node, fallLengh: -10)
            }
        }
    }
    
    // MARK: - PhysicsWorld
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if !isBallBeginContactWithRim && isBallEndContactWithRim {
            if contact.nodeA.physicsBody?.categoryBitMask == BodyType.ball.rawValue && contact.nodeB.physicsBody?.categoryBitMask == BodyType.topPlane.rawValue {
                
                isBallBeginContactWithRim = !isBallBeginContactWithRim
                isBallEndContactWithRim = !isBallEndContactWithRim
            }
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        if isBallBeginContactWithRim && !isBallEndContactWithRim {
            if contact.nodeA.physicsBody?.categoryBitMask == BodyType.ball.rawValue && contact.nodeB.physicsBody?.categoryBitMask == BodyType.bottomPlane.rawValue {
                score += 1

                isBallBeginContactWithRim = !isBallBeginContactWithRim
                isBallEndContactWithRim = !isBallEndContactWithRim
            }
        }
    }
    
    
    // MARK: - @IBActions
    @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
        if isHoopAdded {
            guard let ballNode = getBallNode() else {
                return
            }
            
            sceneView.scene.rootNode.addChildNode(ballNode)
        } else {
            let location = sender.location(in: sceneView)
            
            guard let result = sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else {
                return
            }
            
            guard let anchor = result.anchor as? ARPlaneAnchor, anchor.alignment == .vertical else {
                return
            }
            
            // Get hoop node and set it coordinates
            let hoopNode = getHoopNode()
            hoopNode.simdTransform = result.worldTransform
            hoopNode.eulerAngles.x -= .pi / 2
            
            isHoopAdded = true
            sceneView.scene.rootNode.addChildNode(hoopNode)
            
            stackView.isHidden = false
        }
    }
    
    @IBAction func restartButtonTapped(_ sender: UIButton) {
        restartGame()
    }
    
}
