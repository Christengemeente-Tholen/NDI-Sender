import UIKit
import AVFoundation

class ViewController: UIViewController {
    private let minimumZoom: CGFloat = 1.0
    private let maximumZoom: CGFloat = 10.0
    private var lastZoomFactor: CGFloat = 1.0
    
    private var cameraManager = CameraManager()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var sendButton: UIButton!
    private var torchOn: Bool = false
    
    private let gridLayer = CALayer()
    private var gridLinesOn: Bool = false
    
    private let deviceLevel = DeviceLevel()
    private var deviceLevelOn: Bool = false

    @IBOutlet weak var resolutionMenu: UIBarButtonItem!
    @IBOutlet weak var zoomProgressBar: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraManager.setupCamera()
        previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer?.connection?.videoOrientation = transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.windows.first!.windowScene!.interfaceOrientation.rawValue)!)
        
        // detect if the application is running in the foreground or background
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        let autoFocusClick = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(sender:)))
        view.addGestureRecognizer(autoFocusClick)
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action:#selector(pinch(_:)))
        view.addGestureRecognizer(pinchRecognizer)
        
        setupPopUpButton()
        view.layer.insertSublayer(gridLayer, above: previewLayer)
    }
    
    // Dont send if the app isn't visable
    @objc func appMovedToBackground() {
        cameraManager.privStopSending()
    }
    
    @objc func appMovedToForeground() {
        if cameraManager.sendState {
            cameraManager.privStartSending()
        }
    }
    
    @IBAction func flashlight(_ sender: UIBarItem) {
        torchOn = torchOn ? false : true
        cameraManager.toggleTorch(on: torchOn)
        sender.image = UIImage(systemName: "flashlight.\( torchOn ? "on": "off" ).fill")
    }
    
    @IBAction func showLevel(_ sender: UIBarItem) {
        deviceLevelOn = deviceLevelOn ? false : true
        deviceLevel.draw(view, drawLines: deviceLevelOn)
        sender.image = UIImage(systemName: "level\( deviceLevelOn ? ".fill": "" )")
    }
    
    @IBAction func gridLines(_ sender: UIBarItem) {
        gridLinesOn = gridLinesOn ? false : true
        GridLines().draw(view, gridLayer, drawLines: gridLinesOn)
    }
    
    @IBAction func useMic(_ sender: UIBarItem) {
        cameraManager.toggleMic()
        sender.image = UIImage(systemName: "mic\( cameraManager.sendAudio ? "": ".slash" )")
    }
    
    private func transformOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            case .portraitUpsideDown:
                return .portraitUpsideDown
            default:
                return .portrait
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) -> Void in
            self.previewLayer?.connection?.videoOrientation = self.transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.windows.first!.windowScene!.interfaceOrientation.rawValue)!)
                self.previewLayer?.frame.size = self.view.frame.size
            }, completion: { (context) -> Void in
        })
        deviceLevel.checkOrientation(view)
        cameraManager.checkOrientation()
        
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        guard let device = cameraManager.videoCaptureDevice else { return }

        // Return zoom value between the minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }

        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }

        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)

        // update zoom bar
        zoomProgressBar.setProgress(Float((newScaleFactor - minimumZoom) / (maximumZoom - minimumZoom)), animated: true)
        
        switch pinch.state {
            case .began: fallthrough
            case .changed: update(scale: newScaleFactor)
            case .ended:
                lastZoomFactor = minMaxZoom(newScaleFactor)
                update(scale: lastZoomFactor)
            default: break
        }
    }
    
    @objc func handleTapToFocus(sender: UITapGestureRecognizer) {
        guard let device = cameraManager.videoCaptureDevice else { return }
        
        let focusPoint = sender.location(in: view)
        let focusScaledPointX = focusPoint.x / view.frame.size.width
        let focusScaledPointY = focusPoint.y / view.frame.size.height
        if device.isFocusModeSupported(.autoFocus) && device.isFocusPointOfInterestSupported {
            do {
                try device.lockForConfiguration()
            } catch {
                print("ERROR: Could not lock camera device for configuration")
                return
            }

            device.focusMode = .autoFocus
            device.focusPointOfInterest = CGPointMake(focusScaledPointX, focusScaledPointY)

            device.unlockForConfiguration()
        }
    }
    
    @IBAction func onClick(_ sender: UIBarButtonItem) {
        if !cameraManager.isSending {
            cameraManager.startSending()
        } else {
            cameraManager.stopSending()
        }
        sender.image = UIImage(systemName: "record.circle\( cameraManager.isSending ? ".fill": "" )")
        sender.tintColor = cameraManager.isSending ? .systemGray : .systemRed
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.previewLayer?.frame.size = self.view.frame.size
        cameraManager.startCapture()
        deviceLevel.onVisible(view)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraManager.stopCapture()
    }

    private func setupPopUpButton() {
        let currentPreset = self.cameraManager.captureSession.sessionPreset
        
        var menuItems = [
            UIAction(title: "480p", state: currentPreset == .vga640x480 ? .on : .off, handler: { (_: UIAction) -> Void in
                self.cameraManager.changeSessionPreset(preset: .vga640x480)
                self.setupPopUpButton()
            }),
            UIAction(title: "720p", state: currentPreset == .hd1280x720 ? .on : .off, handler: { (_: UIAction) -> Void in
                self.cameraManager.changeSessionPreset(preset: .hd1280x720)
                self.setupPopUpButton()
            }),
            UIAction(title: "1080p", state: currentPreset == .hd1920x1080 ? .on : .off, handler: { (_: UIAction) -> Void in
                self.cameraManager.changeSessionPreset(preset: .hd1920x1080)
                self.setupPopUpButton()
            })
        ]
        
        if cameraManager.currentOutput() == .back {
            menuItems.append(UIAction(title: "4K", state: currentPreset == .hd4K3840x2160 ? .on : .off, handler: { (_: UIAction) in
                self.cameraManager.changeSessionPreset(preset: .hd4K3840x2160)
                self.setupPopUpButton()
            }))
        }
        resolutionMenu.menu = UIMenu(children: menuItems)
    }
    
    @IBAction func SwitchCamera(_ sender: UIBarItem) {
        cameraManager.switchCamera()
        // change resolution option list
        setupPopUpButton()
    }
}
