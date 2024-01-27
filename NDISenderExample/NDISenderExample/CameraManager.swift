import UIKit
import Foundation
import AVFoundation

@objc
protocol CameraCaptureDelegate: AnyObject {
    func captureVideoOutput(sampleBuffer: CMSampleBuffer)
    @objc optional func captureAudioOutput(sampleBuffer: CMSampleBuffer)
}

class CameraManager: NSObject {
    private var ndiWrapper: NDIWrapper?
    private var audioCapture: AudioCapture?
    public var videoCaptureDevice: AVCaptureDevice?
    public let captureSession = AVCaptureSession()
    private var currentCameraInput: AVCaptureInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    private let dataOutputQueue = DispatchQueue(label: "VideoDataQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    weak var delegate: CameraCaptureDelegate?
    public var isSending: Bool = false // used for internal state if sending
    public var sendState: Bool = false // used for button state
    public var sendAudio: Bool = true
            
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
    
    func toggleTorch(on: Bool) {
        guard
            let device = AVCaptureDevice.default(for: AVMediaType.video),
            device.hasTorch
        else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }
    
    func toggleMic() {
        self.sendAudio = !self.sendAudio
    }
    
    func checkOrientation() {
        // restart the sender against errors when changing orientation
        privStopSending()
        privCheckOrientation()
        privStartSending()
    }
    
    func privCheckOrientation() {
        videoDataOutput.connection(with: .video)?.videoOrientation = self.transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.windows.first!.windowScene!.interfaceOrientation.rawValue)!)
    }
    
    func setupCamera() {
        ndiWrapper = NDIWrapper()
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        videoCaptureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
        
        captureSession.sessionPreset = .vga640x480
        
        self.videoCaptureDevice = videoCaptureDevice
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            currentCameraInput = videoInput
        }
        
        // Add a video data output
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA] as [String : Any]
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            privCheckOrientation()
            
        } else {
            debugPrint("Could not add video data output to the session")
        }
        
        setupMic()
    }
    
    func setupMic() {
        guard let audio = AVCaptureDevice.default(for: .audio),
        let audioInput = try? AVCaptureDeviceInput(device: audio) else { return }
        
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        
        if captureSession.canAddOutput(audioDataOutput) {
            captureSession.addOutput(audioDataOutput)
            audioDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        }
        
        audioCapture = AudioCapture(processingCallback: { buffer, time in
            guard let ndiWrapper = self.ndiWrapper, self.isSending, self.sendAudio else { return }
            ndiWrapper.sendAudioBuffer(buffer)
        })
    }
    
    func startCapture() {
        #if arch(arm64)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
        #endif
    }
    
    func stopCapture() {
        #if arch(arm64)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
        }
        #endif
    }
    
    func changeSessionPreset(preset: AVCaptureSession.Preset) {
        // restart the sender against errors when changing preset
        self.privStopSending()
        self.captureSession.sessionPreset = preset
        self.privStartSending()
    }
    
    func startSending() {
        sendState = true
        self.privStartSending()
    }

    func stopSending() {
        sendState = false
        self.privStopSending()
    }
    
    func privStartSending() {
        isSending = true
        guard let ndiWrapper = self.ndiWrapper else { return }
        ndiWrapper.start(UIDevice.current.name)
    }
    
    func privStopSending() {
        isSending = false
        guard let ndiWrapper = self.ndiWrapper else { return }
        ndiWrapper.stop()
    }
}

// MARK: Switching Camera
extension CameraManager {
    func currentOutput() -> AVCaptureDevice.Position {
        return ((currentCameraInput as? AVCaptureDeviceInput)?.device.position == .back) ?
            AVCaptureDevice.Position.back : .front
    }
    
    func switchCamera() {
        privStopSending()
        
        #if arch(arm64)
        let nextPosition = ((currentCameraInput as? AVCaptureDeviceInput)?.device.position == .front) ? AVCaptureDevice.Position.back : .front
        
        // front camera doesnt support 4k
        if nextPosition == .front && captureSession.sessionPreset == .hd4K3840x2160 {
            captureSession.sessionPreset = .hd1920x1080
        }
        
        if let currentCameraInput = currentCameraInput {
            captureSession.removeInput(currentCameraInput)
        }
                
        if let newCamera = cameraDevice(position: nextPosition),
            let newVideoInput: AVCaptureDeviceInput = try? AVCaptureDeviceInput(device: newCamera),
            captureSession.canAddInput(newVideoInput) {

            captureSession.addInput(newVideoInput)
            currentCameraInput = newVideoInput
            
            privCheckOrientation()
            videoDataOutput.connection(with: .video)?.isVideoMirrored = nextPosition == .front
        }
                
        #endif
        // restart the sender against errors when replacing camera
        if sendState {
            privStartSending()
        }
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
        for device in discoverySession.devices where device.position == position {
            return device
        }

        return nil
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let ndiWrapper = self.ndiWrapper, isSending else { return }
        ndiWrapper.send(sampleBuffer)
    }
}
