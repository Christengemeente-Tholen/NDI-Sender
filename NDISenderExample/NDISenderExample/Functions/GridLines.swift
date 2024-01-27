//
//  GridLines.swift
//  NDISenderExample
//
//  Created by Zefanja Jobse on 22/04/2023.
//

import UIKit

class GridLines: NSObject {
    private let lineColor = UIColor.white.withAlphaComponent(0.5).cgColor
    
    public func draw(_ view: UIView, _ gridLayer: CALayer, drawLines: Bool) {
        let viewHeight = view.bounds.height;
        let viewWidth = view.bounds.width;
        
        if drawLines {
            drawLineFromPoint(gridLayer, start: CGPoint(x: viewWidth*0.25, y: 0), end: CGPoint(x: viewWidth*0.25, y: viewHeight))
            drawLineFromPoint(gridLayer, start: CGPoint(x: viewWidth*0.75, y: 0), end: CGPoint(x: viewWidth*0.75, y: viewHeight))
            
            drawLineFromPoint(gridLayer, start: CGPoint(x: 0, y: viewHeight*0.25), end: CGPoint(x: viewWidth, y: viewHeight*0.25))
            drawLineFromPoint(gridLayer, start: CGPoint(x: 0, y: viewHeight*0.75), end: CGPoint(x: viewWidth, y: viewHeight*0.75))
        } else {
            gridLayer.sublayers?.removeAll()
        }
    }
    
    func drawLineFromPoint(_ gridLayer: CALayer, start: CGPoint, end: CGPoint) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = lineColor
        shapeLayer.lineWidth = 1.0
        gridLayer.addSublayer(shapeLayer)
    }
}
