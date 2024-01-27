//
//  DeviceLevel.swift
//  NDISenderExample
//
//  Created by Zefanja Jobse on 22/04/2023.
//

import UIKit
import CoreMotion

class DeviceLevel: NSObject {
    private let lineColor = UIColor.red.withAlphaComponent(0.5).cgColor
    private var motionManager = CMMotionManager()
    private var deviceLevelView = UIView()
    
    private var currentOrientation: UIDeviceOrientation = .landscapeLeft
    private var orientationObserver: NSObjectProtocol? = nil
    private var text = UILabel(frame:CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 256, height: 30)))
    let notification = UIDevice.orientationDidChangeNotification
    
    @Published var pitch: Double = 0
    @Published var roll: Double = 0
    
    func draw(_ view: UIView, drawLines: Bool) {
        if drawLines {
            view.addSubview(deviceLevelView)
        } else {
            deviceLevelView.removeFromSuperview()
        }
    }
    
    func checkOrientation(_ view: UIView, startup: Bool = false) {
        deviceLevelView.transform = CGAffineTransformMakeRotation(0)
        deviceLevelView.frame = CGRect(x: 0, y: 0, width: 256, height: 5)
        deviceLevelView.center = startup ? view.center : CGPoint(x: view.bounds.height/2, y: view.bounds.width/2)
        deviceLevelView.backgroundColor = .white.withAlphaComponent(0.5)
        deviceLevelView.addSubview(text)
    }
    
    func onVisible(_ view: UIView) {
        text.font = UIFont(name: text.font.fontName, size: 10)
        text.textAlignment = NSTextAlignment.center
        
        checkOrientation(view, startup: true)
        orientationObserver = NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) { [weak self] _ in
            switch UIDevice.current.orientation {
            case .faceUp, .faceDown, .unknown:
                break
            default:
                self?.currentOrientation = UIDevice.current.orientation
            }
        }
        
        motionManager.startDeviceMotionUpdates()
        motionManager.gyroUpdateInterval = 0.1
        motionManager.startGyroUpdates(to: OperationQueue.current!) { (data, error) in
            if let data = self.motionManager.deviceMotion {
                (self.roll, self.pitch) = self.currentOrientation.deviceRotation(data.attitude)
                self.deviceLevelView.transform = CGAffineTransformMakeRotation(self.roll)
                self.text.text = String(format: "%.2f", self.roll)
            }
        }
    }
    
    private func drawLineFromPoint(start: CGPoint, end: CGPoint) -> CAShapeLayer {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = lineColor
        shapeLayer.lineWidth = 1.0
        return shapeLayer
    }
}


extension UIDeviceOrientation {
    func deviceRotation(_ attitude: CMAttitude) -> (roll: Double, pitch: Double) {
        let extra = Double.pi / 2
        switch self {
        case .unknown, .faceUp, .faceDown:
            return (-attitude.roll, attitude.pitch - extra)
        case .landscapeLeft:
            return (-attitude.pitch, attitude.roll - extra)
        case .portrait:
            return (-attitude.roll, -attitude.pitch - extra)
        case .portraitUpsideDown:
            return (attitude.roll, attitude.pitch - extra)
        case .landscapeRight:
            return (attitude.pitch, -attitude.roll - extra)
        @unknown default:
            return (-attitude.roll, -attitude.pitch - extra)
        }
    }
}
