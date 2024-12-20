import ARKit
import Foundation
import SceneKit
import UIKit
import Photos
import AVFoundation
import Vision

class MainViewController: UIViewController {
    var dragOnInfinitePlanesEnabled = false
    var currentGesture: Gesture?
    
    var use3DOFTrackingFallback = false
    var screenCenter: CGPoint?
    
    let session = ARSession()
    var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
    
    var trackingFallbackTimer: Timer?
    
    @IBOutlet weak var suggestionView: UITextView!
    // Use average of recent virtual object distances to avoid rapid changes in object scale.
    var recentVirtualObjectDistances = [CGFloat]()
    
    let DEFAULT_DISTANCE_CAMERA_TO_OBJECTS = Float(10)
    
    let gravity: Float = -1
    var play: Bool = false
    var audioPlayer: AVAudioPlayer?
    
    var count = 0
    lazy var countLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.textColor = .red
        label.font = UIFont.boldSystemFont(ofSize: 100)
        label.isHidden = true
        return label
    }()
    
    lazy var menuContentView: MenuContentView = {
        let view =  MenuContentView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()
    
    lazy var foldButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .yellow
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(onClickfoldButton), for: .touchUpInside)
        return button
    }()
    
    var menuViewWidthConst: NSLayoutConstraint?
    
    let data: [(String, String)] = [
        ("candle", "This is menu item 1."),
        ("cup", "This is menu item 2."),
        ("candle", "This is menu item 3."),
        ("chair", "This is menu item 4."),
        ("lamp", "This is menu item 5."),
        ("vase", "This is menu item 6.")
    ]
    
    var focusPoint: CGPoint {
        return CGPoint(
            x: sceneView.bounds.size.width / 2,
            y: sceneView.bounds.size.height - (sceneView.bounds.size.height / 1.618))
    }
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var previousHandPosition: CGPoint? // 缓存上一帧手的位置（用于挥手手势）
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Setting.registerDefaults()
        setupScene()
        setupDebug()
        setupUIControls()
        setupFocusSquare()
        setupVision()
        updateSettings()
        resetVirtualObject()
        setupMenuView()
        loadAudio()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
        restartPlaneDetection()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    func loadAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        if let soundURL = Bundle.main.url(forResource: "sound", withExtension: "wav") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = 1.0
            } catch {
                print("Error load: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - ARKit / ARSCNView
    var use3DOFTracking = false {
        didSet {
            if use3DOFTracking {
                sessionConfig = ARWorldTrackingConfiguration()
            }
            sessionConfig.isLightEstimationEnabled = UserDefaults.standard.bool(for: .ambientLightEstimation)
            session.run(sessionConfig)
        }
    }
    @IBOutlet var sceneView: ARSCNView!
    
    func setupMenuView() {
        let jsonString = """
        [
            {
                "itemName": "vase", 
                "itemId": 1
            }, 
            {
                "itemName": "lamp", 
                "itemId": 2
            }, 
            {
                "itemName": "chair", 
                "itemId": 3
            }, 
            {
                "itemName": "cup", 
                "itemId": 4
            }, 
            {
                "itemName": "candle", 
                "itemId": 5
            },
        ]
        """
        MenuObjectManager.share.convertMenuToObject(jsonString: jsonString)
        menuContentView.data = MenuObjectManager.share.menuVirtualObjects
        view.addSubview(menuContentView)
        view.addSubview(foldButton)
        countLabel.center = view.center
        countLabel.sizeToFit()
        view.addSubview(countLabel)
        menuViewWidthConst =  menuContentView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width / 3)
        menuViewWidthConst!.isActive = true
        NSLayoutConstraint.activate([
            menuContentView.topAnchor.constraint(equalTo: view.topAnchor),
            menuContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menuContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            foldButton.centerYAnchor.constraint(equalTo: menuContentView.centerYAnchor),
            foldButton.leadingAnchor.constraint(equalTo: menuContentView.leadingAnchor, constant: -10),
            foldButton.widthAnchor.constraint(equalToConstant: 20),
            foldButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc
    func onClickfoldButton(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        menuViewWidthConst?.constant = sender.isSelected ? 0 : UIScreen.main.bounds.width / 3
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Ambient Light Estimation
    func toggleAmbientLightEstimation(_ enabled: Bool) {
        if enabled {
            if !sessionConfig.isLightEstimationEnabled {
                sessionConfig.isLightEstimationEnabled = true
                session.run(sessionConfig)
            }
        } else {
            if sessionConfig.isLightEstimationEnabled {
                sessionConfig.isLightEstimationEnabled = false
                session.run(sessionConfig)
            }
        }
    }
    
    // MARK: - Virtual Object Loading
    var isLoadingObject: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.settingsButton.isEnabled = !self.isLoadingObject
                self.addObjectButton.isEnabled = !self.isLoadingObject
                self.screenshotButton.isEnabled = !self.isLoadingObject
                self.restartExperienceButton.isEnabled = !self.isLoadingObject
            }
        }
    }
    
    @IBOutlet weak var addObjectButton: UIButton!
    
    @IBAction func chooseObject(_ button: UIButton) {
        play = true
        button.isUserInteractionEnabled = false
        let countdownTimer = CountdownTimer(startTime: 60, timeUpHandler: { [weak self] in
            self?.resetVirtualObject()
            self?.play = false
        }, tickHandler: { [weak self] remainingTime in
            self?.addObjectButton.setTitleColor(.systemGray, for: .normal)
            self?.addObjectButton.layer.borderColor = UIColor.systemGray.cgColor
            self?.addObjectButton.setTitle("\(remainingTime)s", for: .normal)
        })
        countdownTimer.start()
        
        if !play {
            count = 0
            countLabel.isHidden = true
            button.isUserInteractionEnabled = true
        }
        return
        // Abort if we are about to load another object to avoid concurrent modifications of the scene.
        //        if isLoadingObject { return }
        
        textManager.cancelScheduledMessage(forType: .contentPlacement)
        
        let rowHeight = 45
        let popoverSize = CGSize(width: 250, height: rowHeight * VirtualObjectSelectionViewController.COUNT_OBJECTS)
        
        let objectViewController = VirtualObjectSelectionViewController(size: popoverSize)
        objectViewController.delegate = self
        objectViewController.modalPresentationStyle = .popover
        objectViewController.popoverPresentationController?.delegate = self
        self.present(objectViewController, animated: true, completion: nil)
        
        objectViewController.popoverPresentationController?.sourceView = button
        objectViewController.popoverPresentationController?.sourceRect = button.bounds
    }
    
    // MARK: - Planes
    
    var planes = [ARPlaneAnchor: Plane]()
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let pos = SCNVector3.positionFromTransform(anchor.transform)
        textManager.showDebugMessage("NEW SURFACE DETECTED AT \(pos.friendlyString())")
        
        let plane = Plane(anchor, showDebugVisuals)
        
        planes[anchor] = plane
        node.addChildNode(plane)
        
        textManager.cancelScheduledMessage(forType: .planeEstimation)
        textManager.showMessage("SURFACE DETECTED")
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
        }
    }
    
    func restartPlaneDetection() {
        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
        
        // reset timer
        if trackingFallbackTimer != nil {
            trackingFallbackTimer!.invalidate()
            trackingFallbackTimer = nil
        }
        
        textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .planeEstimation)
    }
    
    // MARK: - Focus Square
    var focusSquare: FocusSquare?
    
    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
        sceneView.scene.rootNode.addChildNode(focusSquare!)
        
        textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
    }
    
    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
        
        let virtualObject = VirtualObjectsManager.shared.getVirtualObjectSelected()
        if virtualObject != nil && sceneView.isNode(virtualObject!, insideFrustumOf: sceneView.pointOfView!) {
            focusSquare?.hide()
        } else {
            focusSquare?.unhide()
        }
        let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
        if let worldPos = worldPos {
            focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
            textManager.cancelScheduledMessage(forType: .focusSquare)
        }
    }
    
    // MARK: - Hit Test Visualization
    
    var hitTestVisualization: HitTestVisualization?
    
    var showHitTestAPIVisualization = UserDefaults.standard.bool(for: .showHitTestAPI) {
        didSet {
            UserDefaults.standard.set(showHitTestAPIVisualization, for: .showHitTestAPI)
            if showHitTestAPIVisualization {
                hitTestVisualization = HitTestVisualization(sceneView: sceneView)
            } else {
                hitTestVisualization = nil
            }
        }
    }
    
    // MARK: - Debug Visualizations
    
    @IBOutlet var featurePointCountLabel: UILabel!
    
    func refreshFeaturePoints() {
        guard showDebugVisuals else {
            return
        }
        
        guard let cloud = session.currentFrame?.rawFeaturePoints else {
            return
        }
        
        DispatchQueue.main.async {
            self.featurePointCountLabel.text = "Features: \(cloud.__count)".uppercased()
        }
    }
    
    var showDebugVisuals: Bool = UserDefaults.standard.bool(for: .debugMode) {
        didSet {
            featurePointCountLabel.isHidden = !showDebugVisuals
            debugMessageLabel.isHidden = !showDebugVisuals
            messagePanel.isHidden = !showDebugVisuals
            planes.values.forEach { $0.showDebugVisualization(showDebugVisuals) }
            sceneView.debugOptions = []
            if showDebugVisuals {
                sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
            }
            UserDefaults.standard.set(showDebugVisuals, for: .debugMode)
        }
    }
    
    func setupDebug() {
        messagePanel.layer.cornerRadius = 3.0
        messagePanel.clipsToBounds = true
    }
    
    // MARK: - UI Elements and Actions
    
    @IBOutlet weak var messagePanel: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var debugMessageLabel: UILabel!
    
    var textManager: TextManager!
    
    func setupUIControls() {
        textManager = TextManager(viewController: self)
        debugMessageLabel.isHidden = true
        featurePointCountLabel.text = ""
        debugMessageLabel.text = ""
        messageLabel.text = ""
    }
    
    @IBOutlet weak var restartExperienceButton: UIButton!
    var restartExperienceButtonIsEnabled = true
    
    @IBAction func restartExperience(_ sender: Any) {
        guard restartExperienceButtonIsEnabled, !isLoadingObject else {
            return
        }
        
        DispatchQueue.main.async {
            self.restartExperienceButtonIsEnabled = false
            
            self.textManager.cancelAllScheduledMessages()
            self.textManager.dismissPresentedAlert()
            self.textManager.showMessage("STARTING A NEW SESSION")
            self.use3DOFTracking = false
            
            self.setupFocusSquare()
            //			self.loadVirtualObject()
            self.restartPlaneDetection()
            
            self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
            
            // Disable Restart button for five seconds in order to give the session enough time to restart.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                self.restartExperienceButtonIsEnabled = true
            })
        }
    }
    
    @IBOutlet weak var screenshotButton: UIButton!
    @IBAction func takeSnapShot() {
        guard sceneView.session.currentFrame != nil else { return }
        focusSquare?.isHidden = true
        removeVirtualObjectSelected()
        
        //		let imagePlane = SCNPlane(width: sceneView.bounds.width / 6000, height: sceneView.bounds.height / 6000)
        //		imagePlane.firstMaterial?.diffuse.contents = sceneView.snapshot()
        //		imagePlane.firstMaterial?.lightingModel = .constant
        //
        //		let planeNode = SCNNode(geometry: imagePlane)
        //		sceneView.scene.rootNode.addChildNode(planeNode)
        //
        //		focusSquare?.isHidden = false
    }
    
    func removeVirtualObjectSelected() {
        VirtualObjectsManager.shared.removeVirtualObjectSelected()
    }
    
    // MARK: - Settings
    
    @IBOutlet weak var settingsButton: UIButton!
    
    @IBAction func showSettings(_ button: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let settingsViewController = storyboard.instantiateViewController(
            withIdentifier: "settingsViewController") as? SettingsViewController else {
            return
        }
        
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSettings))
        settingsViewController.navigationItem.rightBarButtonItem = barButtonItem
        settingsViewController.title = "Options"
        
        let navigationController = UINavigationController(rootViewController: settingsViewController)
        navigationController.modalPresentationStyle = .popover
        navigationController.popoverPresentationController?.delegate = self
        navigationController.preferredContentSize = CGSize(width: sceneView.bounds.size.width - 20,
                                                           height: sceneView.bounds.size.height - 50)
        self.present(navigationController, animated: true, completion: nil)
        
        navigationController.popoverPresentationController?.sourceView = settingsButton
        navigationController.popoverPresentationController?.sourceRect = settingsButton.bounds
    }
    
    @objc
    func dismissSettings() {
        self.dismiss(animated: true, completion: nil)
        updateSettings()
    }
    
    private func updateSettings() {
        let defaults = UserDefaults.standard
        
        showDebugVisuals = defaults.bool(for: .debugMode)
        toggleAmbientLightEstimation(defaults.bool(for: .ambientLightEstimation))
        dragOnInfinitePlanesEnabled = defaults.bool(for: .dragOnInfinitePlanes)
        showHitTestAPIVisualization = defaults.bool(for: .showHitTestAPI)
        use3DOFTracking	= defaults.bool(for: .use3DOFTracking)
        use3DOFTrackingFallback = defaults.bool(for: .use3DOFFallback)
        for (_, plane) in planes {
            plane.updateOcclusionSetting()
        }
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
        textManager.blurBackground()
        
        if allowRestart {
            let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
                self.textManager.unblurBackground()
                self.restartExperience(self)
            }
            textManager.showAlert(title: title, message: message, actions: [restartAction])
        } else {
            textManager.showAlert(title: title, message: message, actions: [])
        }
    }
}

// MARK: - ARKit / ARSCNView
extension MainViewController {
    func setupScene() {
        sceneView.setUp(viewController: self, session: session)
        DispatchQueue.main.async {
            self.screenCenter = self.sceneView.bounds.mid
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: !self.showDebugVisuals)
        
        switch camera.trackingState {
        case .notAvailable:
            textManager.escalateFeedback(for: camera.trackingState, inSeconds: 5.0)
        case .limited:
            if use3DOFTrackingFallback {
                // After 10 seconds of limited quality, fall back to 3DOF mode.
                trackingFallbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { _ in
                    self.use3DOFTracking = true
                    self.trackingFallbackTimer?.invalidate()
                    self.trackingFallbackTimer = nil
                })
            } else {
                textManager.escalateFeedback(for: camera.trackingState, inSeconds: 10.0)
            }
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
            if use3DOFTrackingFallback && trackingFallbackTimer != nil {
                trackingFallbackTimer!.invalidate()
                trackingFallbackTimer = nil
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }
        
        let nsError = error as NSError
        var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
        if let recoveryOptions = nsError.localizedRecoveryOptions {
            for option in recoveryOptions {
                sessionErrorMsg.append("\(option).")
            }
        }
        
        let isRecoverable = (arError.code == .worldTrackingFailed)
        if isRecoverable {
            sessionErrorMsg += "\nYou can try resetting the session or quit the application."
        } else {
            sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
        }
        
        displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        textManager.blurBackground()
        textManager.showAlert(title: "Session Interrupted",
                              message: "The session will be reset after the interruption has ended.")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        textManager.unblurBackground()
        session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
        restartExperience(self)
        textManager.showMessage("RESETTING SESSION")
    }
}

// MARK: Gesture Recognized
extension MainViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
            currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, nil, self)
            currentGesture?.redPackageDelegate = self
            return
        }
        if play {
            return
        }
        if currentGesture == nil {
            currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, object, self)
        } else {
            currentGesture = currentGesture!.updateGestureFromTouches(touches, .touchBegan)
        }
        
        displayVirtualObjectTransform()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            return
        }
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchMoved)
        displayVirtualObjectTransform()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            //            chooseObject(addObjectButton)
            return
        }
        
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchEnded)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            return
        }
        currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchCancelled)
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension MainViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        updateSettings()
    }
}

// MARK: - VirtualObjectSelectionViewControllerDelegate
extension MainViewController:
    VirtualObjectSelectionViewControllerDelegate {
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, object: VirtualObject) {
        loadVirtualObject(object: object)
    }
    
    func loadVirtualObject(object: VirtualObject) {
        analyzeItem(object: object)
        // Show progress indicator
        let spinner = UIActivityIndicatorView()
        spinner.center = addObjectButton.center
        spinner.bounds.size = CGSize(width: addObjectButton.bounds.width - 5, height: addObjectButton.bounds.height - 5)
        sceneView.addSubview(spinner)
        spinner.startAnimating()
        
        DispatchQueue.global().async {
            self.isLoadingObject = true
            object.viewController = self
            VirtualObjectsManager.shared.addVirtualObject(virtualObject: object)
            VirtualObjectsManager.shared.setVirtualObjectSelected(virtualObject: object)
            
            object.loadModel()
            
            DispatchQueue.main.async {
                if let lastFocusSquarePos = self.focusSquare?.lastPosition {
                    self.setNewVirtualObjectPosition(lastFocusSquarePos)
                } else {
                    self.setNewVirtualObjectPosition(SCNVector3Zero)
                }
                
                spinner.removeFromSuperview()
                
                // Update the icon of the add object button
                let buttonImage = UIImage.composeButtonImage(from: object.thumbImage)
                let pressedButtonImage = UIImage.composeButtonImage(from: object.thumbImage, alpha: 0.3)
//                self.addObjectButton.setImage(buttonImage, for: [])
//                self.addObjectButton.setImage(pressedButtonImage, for: [.highlighted])
                self.isLoadingObject = false
            }
        }
    }
}

// MARK: - ARSCNViewDelegate
extension MainViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        refreshFeaturePoints()
        
        DispatchQueue.main.async {
            self.updateFocusSquare()
            self.hitTestVisualization?.render()
            
//             If light estimation is enabled, update the intensity of the model's lights and the environment map
//            			if let lightEstimate = self.session.currentFrame?.lightEstimate {
//            				self.sceneView.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40)
//            			} else {
//            				self.sceneView.enableEnvironmentMapWithIntensity(25)
//            			}
            
            for node in VirtualObjectsManager.shared.getVirtualObjects() {
                let position = node.ringNode.convertPosition(SCNVector3Zero, to: nil)
                let projectedPoint = renderer.projectPoint(position)
                let projectedCGPoint = CGPoint(x: CGFloat(projectedPoint.x), y: CGFloat(projectedPoint.y))
                let distance = projectedCGPoint.distance(to: self.focusPoint)
                if distance < 50 {
                    self.onSelectNode(node: node)
                }
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.addPlane(node: node, anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                if let plane = self.planes[planeAnchor] {
                    plane.update(planeAnchor)
                }
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor, let plane = self.planes.removeValue(forKey: planeAnchor) {
                plane.removeFromParentNode()
            }
        }
    }
}

// MARK: Virtual Object Manipulation
extension MainViewController {
    func displayVirtualObjectTransform() {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
              let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        // Output the current translation, rotation & scale of the virtual object as text.
        let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
        let vectorToCamera = cameraPos - object.position
        
        let distanceToUser = vectorToCamera.length()
        
        var angleDegrees = Int(((object.eulerAngles.y) * 180) / Float.pi) % 360
        if angleDegrees < 0 {
            angleDegrees += 360
        }
        
        let distance = String(format: "%.2f", distanceToUser)
        let scale = String(format: "%.2f", object.scale.x)
        textManager.showDebugMessage("Distance: \(distance) m\nRotation: \(angleDegrees)°\nScale: \(scale)x")
    }
    
    func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {
        
        guard let newPosition = pos else {
            textManager.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
            // Reset the content selection in the menu only if the content has not yet been initially placed.
            if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
                resetVirtualObject()
            }
            return
        }
        
        if instantly {
            setNewVirtualObjectPosition(newPosition)
        } else {
            updateVirtualObjectPosition(newPosition, filterPosition)
        }
    }
    
    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> (position: SCNVector3?,
                                                                          planeAnchor: ARPlaneAnchor?,
                                                                          hitAPlane: Bool) {
        
        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting plane anchors first.
        //    (If any such anchors exist & only within their extents.)
        
        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {
            
            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
            let planeAnchor = result.anchor
            
            // Return immediately - this is the best possible outcome.
            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
        }
        
        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud, but do not return the result yet.
        
        var featureHitTestPosition: SCNVector3?
        var highQualityFeatureHitTestResult = false
        
        let highQualityfeatureHitTestResults =
        sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
        
        if !highQualityfeatureHitTestResults.isEmpty {
            let result = highQualityfeatureHitTestResults[0]
            featureHitTestPosition = result.position
            highQualityFeatureHitTestResult = true
        }
        
        // -------------------------------------------------------------------------------
        // 3. If desired or necessary (no good feature hit test result): Hit test
        //    against an infinite, horizontal plane (ignoring the real world).
        
        if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
            
            let pointOnPlane = objectPos ?? SCNVector3Zero
            
            let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
            if pointOnInfinitePlane != nil {
                return (pointOnInfinitePlane, nil, true)
            }
        }
        
        // -------------------------------------------------------------------------------
        // 4. If available, return the result of the hit test against high quality
        //    features if the hit tests against infinite planes were skipped or no
        //    infinite plane was hit.
        
        if highQualityFeatureHitTestResult {
            return (featureHitTestPosition, nil, false)
        }
        
        // -------------------------------------------------------------------------------
        // 5. As a last resort, perform a second, unfiltered hit test against features.
        //    If there are no features in the scene, the result returned here will be nil.
        
        let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
        if !unfilteredFeatureHitTestResults.isEmpty {
            let result = unfilteredFeatureHitTestResults[0]
            return (result.position, nil, false)
        }
        
        return (nil, nil, false)
    }
    
    func setNewVirtualObjectPosition(_ pos: SCNVector3) {
        
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
              let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        recentVirtualObjectDistances.removeAll()
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)
        
        object.position = cameraWorldPos + cameraToPosition
        
        if object.parent == nil {
            sceneView.scene.rootNode.addChildNode(object)
        }
    }
    
    func resetVirtualObject() {
        VirtualObjectsManager.shared.resetVirtualObjects()
        
        addObjectButton.setTitle("Play", for: .normal)
        addObjectButton.setTitleColor(.systemBlue, for: .normal)
        addObjectButton.layer.borderColor = UIColor.systemBlue.cgColor
        addObjectButton.layer.borderWidth = 0.5
        addObjectButton.setImage(nil, for: .normal)
        addObjectButton.setImage(nil, for: .highlighted)
        addObjectButton.titleLabel?.font = .systemFont(ofSize: 16.0)
        addObjectButton.isUserInteractionEnabled = true
        //        addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        //        addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])
    }
    
    func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
            return
        }
        
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
        var cameraToPosition = pos - cameraWorldPos
        cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)
        
        // Compute the average distance of the object from the camera over the last ten
        // updates. If filterPosition is true, compute a new position for the object
        // with this average. Notice that the distance is applied to the vector from
        // the camera to the content, so it only affects the percieved distance of the
        // object - the averaging does _not_ make the content "lag".
        let hitTestResultDistance = CGFloat(cameraToPosition.length())
        
        recentVirtualObjectDistances.append(hitTestResultDistance)
        recentVirtualObjectDistances.keepLast(10)
        
        if filterPosition {
            let averageDistance = recentVirtualObjectDistances.average!
            
            cameraToPosition.setLength(Float(averageDistance))
            let averagedDistancePos = cameraWorldPos + cameraToPosition
            
            object.position = averagedDistancePos
        } else {
            object.position = cameraWorldPos + cameraToPosition
        }
    }
    
    func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
        guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
              let planeAnchorNode = sceneView.node(for: anchor) else {
            return
        }
        
        // Get the object's position in the plane's coordinate system.
        let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)
        
        if objectPos.y == 0 {
            return; // The object is already on the plane
        }
        
        // Add 10% tolerance to the corners of the plane.
        let tolerance: Float = 0.1
        
        let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
        let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
        let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
        let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
        
        if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
            return
        }
        
        // Drop the object onto the plane if it is near it.
        let verticalAllowance: Float = 0.03
        if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
            textManager.showDebugMessage("OBJECT MOVED\nSurface detected nearby")
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            object.position.y = anchor.transform.columns.3.y
            SCNTransaction.commit()
        }
    }
}

extension MainViewController: MenuContentViewDelegate {
    func menuContentView(contentView: MenuContentView, didSelectAt index: Int) {
        guard let pandaView = PandaLoadingView.showLoading() else { return }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
            PandaLoadingView.dismissLoading(view: pandaView)
            let objct = MenuObjectManager.share.menuVirtualObjects[index]
            let object = VirtualObject(modelName: objct.modelName, fileExtension: objct.fileExtension, thumbImageFilename: objct.modelName, title: objct.title, objct.itemId)
            self.loadVirtualObject(object: object)
        })
    }
}

// MARK: - AI
extension MainViewController {
    func analyzeItem(object: VirtualObject) {
        AICenter.shared.analyzeItem(item: object) { result in
            switch result {
            case .success(let analyzeResult):
                DispatchQueue.main.async {
                    self.suggestionView.text = analyzeResult.suggestionDescription()
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.suggestionView.text = error.localizedDescription
                }
            }
        }
    }
    
    func analyzeOrder() {
        // TODO: change order name, record order items
        AICenter.shared.analyzeOrder(order: "M12", items: VirtualObjectsManager.shared.getVirtualObjects()) { result in
            switch result {
            case .success(let analyzeResult):
                DispatchQueue.main.async {
                    self.suggestionView.text = analyzeResult.suggestionDescription()
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.suggestionView.text = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Focus Ring
extension MainViewController {
    
    func onSelectNode(node: VirtualObject) {
        VirtualObjectsManager.shared.setVirtualObjectSelected(virtualObject: node)
    }
    
    func onSelectionEnded() {
        VirtualObjectsManager.shared.getVirtualObjectSelected()?.onDeselectNode()
    }
}

// MARK: - RedPackage
extension MainViewController: ARSKViewDelegate, RedPackageDelegate  {
    func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        if (arc4random() % 4 == 0 && play) {
            addNode()
        }
        clean()
    }
    
    func addNode() {
        let postion = SCNVector3(Float(Int.getRandomNumber(from: -2, to: 2)) * 5 + Float(Int.getRandomNumber(from: -3, to: 3)), 30, Float(Int.getRandomNumber(from: -2, to: 2)) * 5 + Float(Int.getRandomNumber(from: -3, to: 3)))
        initNodeWithPosition(position: postion)
    }
    
    func clean() {
        for node in self.sceneView.scene.rootNode.childNodes {
            if node.presentation.position.y < -26 {
                node.removeFromParentNode()
            }
        }
    }
    
    func initNodeWithPosition(position: SCNVector3) {
        let node = RedPackageNode.loadRedPackage()
        node.position = position
        sceneView.scene.physicsWorld.gravity = SCNVector3(x: 0, y: gravity, z: 0)
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    func gesture(didSelect nodeName: String) {
        audioPlayer?.play()
        count += 1
        countLabel.text = "x\(count)"
        countLabel.sizeToFit()
        countLabel.isHidden = false
        countLabel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 2.0,
                       options: .curveEaseInOut,
                       animations: {
            self.countLabel.transform = CGAffineTransform.identity
        }, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.countLabel.isHidden = true
            }
        })
    }
}

// MARK: Vision
extension MainViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // 获取摄像头图像
            let pixelBuffer = frame.capturedImage
            
            // 创建 Vision 请求处理器
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try requestHandler.perform([handPoseRequest])
                if let observations = handPoseRequest.results {
                    processHandPoseObservations(observations)
                }
            } catch {
                print("Vision 请求失败: \(error)")
            }
        }
    
    private func setupVision() {
        handPoseRequest.maximumHandCount = 1
    }
    
    private func processHandPoseObservations(_ observations: [VNHumanHandPoseObservation]) {
        guard let observation = observations.first else { return }
        
        do {
            let thumbTip = try observation.recognizedPoint(.thumbTip)
            let indexTip = try observation.recognizedPoint(.indexTip)
            let middleTip = try observation.recognizedPoint(.middleTip)
            let ringTip = try observation.recognizedPoint(.ringTip)
            let littleTip = try observation.recognizedPoint(.littleTip)
            let wrist = try observation.recognizedPoint(.wrist)
            
            if isOKGesture(thumbTip: thumbTip, indexTip: indexTip, middleTip: middleTip, ringTip: ringTip, littleTip: littleTip) {
                handleOKGesture()
            } else if isThumbsUpGesture(thumbTip: thumbTip, indexTip: indexTip, middleTip: middleTip, ringTip: ringTip, littleTip: littleTip, wrist: wrist) {
                handleThumbsUpGesture()
            } else if isWaveGesture(wrist: wrist) {
                handleWaveGesture()
            }
        } catch {
            print("手势检测失败: \(error)")
        }
    }
    
    private func isOKGesture(thumbTip: VNRecognizedPoint, indexTip: VNRecognizedPoint, middleTip: VNRecognizedPoint, ringTip: VNRecognizedPoint, littleTip: VNRecognizedPoint) -> Bool {
        let thumbIndexDistance = hypot(thumbTip.location.x - indexTip.location.x, thumbTip.location.y - indexTip.location.y)
        let thumbMiddleDistance = hypot(thumbTip.location.x - middleTip.location.x, thumbTip.location.y - middleTip.location.y)
        return thumbIndexDistance < 0.1 && thumbMiddleDistance > 0.2
    }
    
    private func isThumbsUpGesture(thumbTip: VNRecognizedPoint, indexTip: VNRecognizedPoint, middleTip: VNRecognizedPoint, ringTip: VNRecognizedPoint, littleTip: VNRecognizedPoint, wrist: VNRecognizedPoint) -> Bool {
        // 拇指向上，其他手指向下
        let thumbToWristY = thumbTip.location.y - wrist.location.y
        return thumbToWristY > 0.5 && indexTip.location.y < wrist.location.y && middleTip.location.y < wrist.location.y
    }
    
    private func isWaveGesture(wrist: VNRecognizedPoint) -> Bool {
        guard let previousPosition = previousHandPosition else {
            previousHandPosition = wrist.location
            return false
        }
        let movement = wrist.location.x - previousPosition.x
        previousHandPosition = wrist.location
        return abs(movement) > 0.2 // 检测手部的左右大幅移动
    }
    
    private func handleOKGesture() {
        showConfirmationMessage("\(VirtualObjectsManager.shared.getVirtualObjectSelected()?.title ?? "") 已添加到订单！")
    }

    private func handleThumbsUpGesture() {
        print("点赞手势: 触发点赞操作")
        showConfirmationMessage("感谢您的点赞！")
    }

    private func handleWaveGesture() {
        print("挥手手势: 触发挥手操作")
        showConfirmationMessage("检测到挥手！")
    }

    private func showConfirmationMessage(_ message: String) {
        let alert = UIAlertController(title: "操作成功", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
