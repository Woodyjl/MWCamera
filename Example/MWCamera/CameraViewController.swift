//
//  CameraViewController.swift
//  MWCamera_Example
//
//  Created by Woody Jean-Louis on 6/8/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit
import MWCamera
import AVFoundation
import AVKit

class CameraViewController: MWCameraViewController {
    let captureButton = CameraButton()

    var blurView: UIView?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension CameraViewController {
    override func loadView() {
        super.loadView()

        self.delegate = self
        self.maximumVideoDuration = 10.0
        self.photoCaptureThreshold = 2.0
        self.videoQuality = .high
        self.videoGravity = .resizeAspectFill
        self.maxZoomScale = 10.0

        self.register(self.captureButton)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.longPressGestureRecognizer?.addTarget(self, action: #selector(handleLongPress(_:)))

        view.addSubview(captureButton)

        captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        captureButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40).isActive = true
        captureButton.widthAnchor.constraint(equalToConstant: 40).isActive = true
        captureButton.heightAnchor.constraint(equalTo: captureButton.widthAnchor).isActive = true

        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        self.blurView = UIVisualEffectView(effect: blurEffect)
        self.blurView?.frame = view.bounds
        self.blurView?.alpha = 0
        self.view.addSubview(self.blurView!)

        self.view.bringSubviewToFront(self.captureButton)

    }
}

extension CameraViewController {
    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            self.captureButton.changeToSquare()
        case .ended:
            if self.recordingDuration <= self.photoCaptureThreshold {
                // Flash the screen to signal that MWCamera took a photo.
                DispatchQueue.main.async {
                    //
                }
            }
        default:
            break
        }
    }
}

extension CameraViewController {
    override func handleApplicationWillResignActive(_ notification: Notification) {
        super.handleApplicationWillResignActive(notification)
        self.freezePreview()
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.blurView?.alpha = 1
            }
        }
    }

    override func handleApplicationDidBecomeActive(_ notification: Notification) {
        super.handleApplicationDidBecomeActive(notification)
        self.unfreezePreview()
        if isSessionRunning {
            DispatchQueue.main.async { [weak self] in
                UIView.animate(withDuration: 0.4) {
                    self?.blurView?.alpha = 0
                }
            }
        }
    }

    override func handleSessionInterruptionEnded(_ notification: Notification) {
        super.handleSessionInterruptionEnded(notification)
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.4) {
                self?.blurView?.alpha = 0
            }
        }
    }

    override func handleSessionDidStartRunning(_ notification: Notification) {
        super.handleSessionDidStartRunning(notification)
        DispatchQueue.main.async { [weak self] in
            if self?.blurView?.alpha == 1 {
                self?.unfreezePreview()
                UIView.animate(withDuration: 0.4) {
                    self?.blurView?.alpha = 0
                }
            }
        }
    }
}

extension CameraViewController: MWCameraDelegate {
    func mwCamera(_ mwCamera: MWCamera, willBeginRecordingVideoAt location: MWCameraLocation) {

    }

    func mwCamera(_ mwCamera: MWCamera, didBeginRecordingVideoAt location: MWCameraLocation) {

    }

    func mwCamera(_ mwCamera: MWCamera, didFinishRecordingVideoAt location: MWCameraLocation) {
        captureButton.changeToCircle()
        captureButton.progress = 0
    }

    func mwCamera(_ mwCamera: MWCamera, didFocusAtPoint point: CGPoint) {
        focusAnimationAt(point)
    }

    func mwCamera(_ mwCamera: MWCamera, didChangeZoomLevelTo zoom: CGFloat) {

    }

    func mwCamera(_ mwCamera: MWCamera, didFinishProcessingVideoAt url: URL) {
        print("playing url: \(url.absoluteString)")
        let player = AVPlayer(url: url)
        let playerController = AVPlayerViewController()
        playerController.player = player
        present(playerController, animated: true) {
            player.play()
        }
    }

    func mwCamera(_ mwCamera: MWCamera, didFailToProcessVideo error: Error) {

    }

    func mwCamera(_ mwCamera: MWCamera, didSwitchCamera location: MWCameraLocation) {

    }

    func mwCamera(_ mwCamera: MWCamera, didUpdateRecordingDurationTo duration: Double) {
        captureButton.progress = duration / maximumVideoDuration
    }

    func mwCamera(_ mwCamera: MWCamera, didCancelRecordingAt url: URL) {
        captureButton.changeToCircle()
        captureButton.progress = 0
    }

    func mwCamera(_ mwCamera: MWCamera, willCaptureImageAt location: MWCameraLocation) {
        captureButton.changeToCircle()
        captureButton.progress = 0

        self.flashPreview()
        //Play capture sound
    }

    func mwCamera(_ mwCamera: MWCamera, didCaptureImageAt location: MWCameraLocation) {

    }

    func mwCamera(_ mwCamera: MWCamera, didFinishProcessing image: UIImage, with properties: CFDictionary) {
        let imageView = UIImageView.init(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.sizeToFit()

        imageView.center = self.view.center

        self.view.addSubview(imageView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            imageView.removeFromSuperview()
        }

        //self.save(cgImage: image.cgImage!, fileType: AVFileType.heic, quality: 1.0, properties: properties)
    }
}

extension CameraViewController {
    private func focusAnimationAt(_ point: CGPoint) {
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        focusView.layer.cornerRadius = 20
        focusView.layer.masksToBounds = true
        focusView.layer.borderColor = UIColor.white.cgColor
        focusView.layer.borderWidth = 1.0
        focusView.center = point
        focusView.alpha = 0.0
        view.addSubview(focusView)

        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut, animations: {
            focusView.alpha = 1.0
            focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }, completion: { (_) in
            UIView.animate(withDuration: 0.15, delay: 0.5, options: .curveEaseInOut, animations: {
                focusView.alpha = 0.0
                focusView.transform = CGAffineTransform(translationX: 0.6, y: 0.6)
            }, completion: { (_) in
                focusView.removeFromSuperview()
            })
        })
    }
}

extension CameraViewController {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UILongPressGestureRecognizer {
            return true
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == doubleTapGestureRecognizer || gestureRecognizer == singleTapGestureRecognizer {
            let location = touch.location(in: view)
            var shouldReceive = true
            shouldReceive = shouldReceive && !captureButton.frame.contains(location)
            if !shouldReceive {
                return false
            }
        }
        return super.gestureRecognizer(gestureRecognizer, shouldReceive: touch)
    }
}

class CameraButton: MWCameraButton {
    var bgPath: UIBezierPath!
    var shapeLayer: CAShapeLayer!
    var progressLayer: CAShapeLayer!
    var progress = 0.0 {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.progressLayer.strokeEnd = CGFloat(newValue)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawButton()
    }

    private func drawButton() {
        self.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        self.layer.cornerRadius = self.bounds.width / 2
        //self.layer.masksToBounds = true

        let xCord = self.bounds.width / 2
        let yCord = self.bounds.height / 2
        let center = CGPoint(x: xCord, y: yCord)
        bgPath = UIBezierPath(
            arcCenter: center, radius: xCord + 15, startAngle: -.pi / 2, endAngle: .pi * 3/2, clockwise: true)
        bgPath.close()

        shapeLayer = CAShapeLayer()
        shapeLayer.path = bgPath.cgPath
        shapeLayer.lineWidth = 8
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.lightGray.withAlphaComponent(0.8).cgColor

        progressLayer = CAShapeLayer()
        progressLayer.path = bgPath.cgPath
        progressLayer.lineWidth = 8
        progressLayer.lineCap = CAShapeLayerLineCap.round
        progressLayer.fillColor = nil
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.strokeEnd = 0.0

        self.layer.addSublayer(shapeLayer)
        self.layer.addSublayer(progressLayer)
    }

    public func changeToSquare() {
        let bounds = self.bounds
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: { [weak self] in
            self?.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            self?.layer.cornerRadius = bounds.width / 4
            self?.backgroundColor = UIColor.red.withAlphaComponent(0.8)
            }, completion: nil)
    }

    public func changeToCircle() {
        let bounds = self.bounds
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveLinear, animations: { [weak self] in
            self?.transform = CGAffineTransform.identity
            self?.layer.cornerRadius = bounds.width / 2
            self?.backgroundColor = UIColor.white.withAlphaComponent(0.8)
            self?.bgPath.apply(CGAffineTransform.identity)
            }, completion: nil)
    }
}
