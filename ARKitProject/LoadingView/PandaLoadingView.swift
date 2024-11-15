//
//  PandaLoadingView.swift
//  ARKitDemo
//
//  Created by Zhou, James on 2024/11/13.
//

import Foundation
import UIKit

class PandaLoadingView: UIView {
    
    static func showLoading() -> UIView? {
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                guard let window = windowScene.windows.first(where: { $0.isKeyWindow })  else { return nil }
                let pandaView = PandaLoadingView()
                let maskView = UIView()
                maskView.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
                window.addSubview(maskView)
                maskView.addSubview(pandaView)
                
                maskView.translatesAutoresizingMaskIntoConstraints = false
                pandaView.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([
                    maskView.topAnchor.constraint(equalTo: window.topAnchor),
                    maskView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                    maskView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                    maskView.trailingAnchor.constraint(equalTo: window.trailingAnchor)
                ])
                NSLayoutConstraint.activate([
                    pandaView.centerXAnchor.constraint(equalTo: maskView.centerXAnchor),
                    pandaView.centerYAnchor.constraint(equalTo: maskView.centerYAnchor),
                    pandaView.widthAnchor.constraint(equalToConstant: 250),
                    pandaView.heightAnchor.constraint(equalToConstant: 250)
                ])
                window.bringSubviewToFront(maskView)
                return maskView
            }
        } else {
            return nil
        }
        return nil
    }
    
    static func dismissLoading(view: UIView) {
        view.removeFromSuperview()
    }
    
    lazy var textLabel: UILabel = {
        let label = UILabel()
        label.text = "AI is generating customer profile"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPanda()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPanda()
    }
}

extension PandaLoadingView {
    private func setupPanda() {
        
        self.layer.cornerRadius = 10
        self.layer.masksToBounds = true
        self.backgroundColor = .white
        
        let bodyLayer = CAShapeLayer()
        bodyLayer.path = UIBezierPath(ovalIn: CGRect(x: 30, y: 50, width: 200, height: 150)).cgPath
        bodyLayer.fillColor = UIColor.white.cgColor
        bodyLayer.strokeColor = UIColor.black.cgColor
        bodyLayer.lineWidth = 5
        layer.addSublayer(bodyLayer)
        
        let leftEyeLayer = CAShapeLayer()
        leftEyeLayer.path = UIBezierPath(ovalIn: CGRect(x: 70, y: 80, width: 40, height: 40)).cgPath
        leftEyeLayer.fillColor = UIColor.black.cgColor
        layer.addSublayer(leftEyeLayer)
        
        let leftEyeLayerWhite = CAShapeLayer()
        leftEyeLayerWhite.path = UIBezierPath(ovalIn: CGRect(x: 80, y: 90, width: 10, height: 10)).cgPath
        leftEyeLayerWhite.fillColor = UIColor.white.cgColor
        layer.addSublayer(leftEyeLayerWhite)
        
        addCirclePath(centerPoint: CGPoint(x: 5, y: 5), layer: leftEyeLayerWhite, startAngle: 0, endAngle: CGFloat.pi * 2)
        
        let rightEyeLayer = CAShapeLayer()
        rightEyeLayer.path = UIBezierPath(ovalIn: CGRect(x: 150, y: 80, width: 40, height: 40)).cgPath
        rightEyeLayer.fillColor = UIColor.black.cgColor
        layer.addSublayer(rightEyeLayer)
        
        let rightEyeLayerWhite = CAShapeLayer()
        rightEyeLayerWhite.path = UIBezierPath(ovalIn: CGRect(x: 180, y: 90, width: 10, height: 10)).cgPath
        rightEyeLayerWhite.fillColor = UIColor.white.cgColor
        layer.addSublayer(rightEyeLayerWhite)
        
        self.addCirclePath(centerPoint: CGPoint(x: -15, y: 5), layer: rightEyeLayerWhite, startAngle: 0, endAngle: CGFloat.pi * 2)
        
        let noseLayer = CAShapeLayer()
        noseLayer.path = UIBezierPath(ovalIn: CGRect(x: 120, y: 120, width: 20, height: 20)).cgPath
        noseLayer.fillColor = UIColor.black.cgColor
        layer.addSublayer(noseLayer)
        
        
        let leftEarLayer = CAShapeLayer()
        leftEarLayer.path = UIBezierPath(ovalIn: CGRect(x: 40, y: 20, width: 50, height: 50)).cgPath
        leftEarLayer.fillColor = UIColor.black.cgColor
        layer.addSublayer(leftEarLayer)
        
        let rightEarLayer = CAShapeLayer()
        rightEarLayer.path = UIBezierPath(ovalIn: CGRect(x: 170, y: 20, width: 50, height: 50)).cgPath
        rightEarLayer.fillColor = UIColor.black.cgColor
        layer.addSublayer(rightEarLayer)
        
        let mouseLayer = CAShapeLayer()
        mouseLayer.path = UIBezierPath(ovalIn: CGRect(x: 110, y: 155, width: 40, height: 30)).cgPath
        mouseLayer.fillColor = UIColor.black.cgColor
        layer.addSublayer(mouseLayer)
        
        addSubview(textLabel)
        NSLayoutConstraint.activate([
            textLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10),
            textLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5),
            textLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -5),
        ])
    }
    
    private func addCirclePath(centerPoint: CGPoint, layer: CAShapeLayer, startAngle: CGFloat, endAngle: CGFloat) {
        let radius: CGFloat = 10
        let center = centerPoint
        let circularPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        let circularAnimation = CAKeyframeAnimation(keyPath: "position")
        circularAnimation.path = circularPath.cgPath
        circularAnimation.duration = 0.5
        circularAnimation.repeatCount = .infinity
        circularAnimation.calculationMode = .paced
        
        layer.add(circularAnimation, forKey: "circularMovement")
    }
}
