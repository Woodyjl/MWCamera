//
//  MWCameraViewControlla.swift
//  MWCamera
//
//  Created by Woody Jean-Louis on 5/28/19.
//

import UIKit
import AVFoundation

open class MWCameraViewController: MWBaseCameraViewController {

    // Variable for storing previous zoom scale
    private var startingZoomScale = CGFloat(1.0)
    // UIView for front facing flash
    private var flashView: UIView?
    // The previous brightness level of the device
    private var previousScreenBrightness: CGFloat = 0.0
    //
    private var shouldResetZoom = false
    /// Used ignore gesture calls after video is done recording.
    private var shouldIgnore = false
    //
    private var timer: Timer?
    //
    private var timePassed = 0.0
    //
    private var shouldStop = false
    //
    private var shouldCreateTimer = false

    // Public access to Pinch Gesture
    private(set) public var pinchGestureRecognizer: UIPinchGestureRecognizer!
    // Public access to tap Gesture
    private(set) public var singleTapGestureRecognizer: UITapGestureRecognizer!
    // Public access to tap Gesture
    private(set) public var doubleTapGestureRecognizer: UITapGestureRecognizer!
    //
    private(set) public var isFlashLocked = false
    //
    private(set) public var isZoomLocked = false

    // Sets whether flash is enabled for video capture
    public var isFlashEnabled = false
    // Sets whether Pinch to Zoom is enabled for the capture session
    public var isPinchToZoomEnabled = true
    // Sets the maximum zoom scale allowed during gestures gesture
    public var maxZoomScale = CGFloat.greatestFiniteMagnitude
    // Variable for storing minimum zoom scale before Pinch to Zoom begins
    public var minZoomScale = CGFloat(1.0)
    // Sets whether Tap to Focus and Tap to Adjust Exposure is enabled for the capture session
    public var isTapToFocusEnabled = true
    //
    public var isPanToZoomEnabled = true

    // Sets whether a double tap to switch cameras is supported
    public var isDoubleTapToSwitchCameraEnabled = true

    // (https://developer.apple.com/reference/avfoundation/avcapturevideopreviewlayer/1386708-videogravity)
    public var videoGravity: AVLayerVideoGravity {
        get {
            return captureView.videoPreviewLayer.videoGravity
        }
        set {
            captureView.videoPreviewLayer.videoGravity = newValue
        }
    }

    // delegate
    public weak var delegate: MWCameraDelegate?
    /// The time interval in which didUpdateRecordingDurationTo is called
    public var videoTimeInterval = 0.1
    // In seconds
    public var maximumVideoDuration = 100000.0
    //
    public var photoCaptureThreshold = 2.0 {
        willSet { assert(newValue > 0, "[MWCamera]: photoCaptureThreshold should be positive") }
    }
    //
    public var stopsRecordingOnTouchUp = true
    // distance in points for the full zoom range (e.g. min to max), could be UIScreen.main.bounds.height
    public var zoomPanMaxLength: CGFloat = UIScreen.main.bounds.height

    public override init() {
        super.init()

        self.addGestureRecognizers()
        self.captureView.frame = self.view.bounds
        self.view.addSubview(self.captureView)
        self.view.sendSubviewToBack(self.captureView)

        self.view.isUserInteractionEnabled = true
        self.captureView.session = self.session
        self.captureView.videoPreviewLayer.connection?.videoOrientation = orientation
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MWCameraViewController {
    public override func startRecording() {
        UIApplication.shared.isIdleTimerDisabled = true
        super.startRecording()
    }

    public override func stopRecording() {
        super.stopRecording()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    public override func cancelRecording() {
        super.cancelRecording()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    public override func capturePhoto(after deadline: TimeInterval = 0) {
        let newDeadline = self.isFlashEnabled && deadline == 0 ? 1.2 : deadline
        super.capturePhoto(after: newDeadline)
    }

    public func focus(at point: CGPoint) {
        let screenSize = captureView.bounds.size
        let xPoint = point.y / screenSize.height
        let yPoint = 1.0 - point.x / screenSize.width
        let focusPoint = CGPoint(x: xPoint, y: yPoint)

        guard let videoDevice = captureDevice else { return }

        do {
            try videoDevice.lockForConfiguration()

            if videoDevice.isFocusPointOfInterestSupported {
                videoDevice.focusPointOfInterest = focusPoint
                videoDevice.focusMode = .autoFocus
            }

            videoDevice.unlockForConfiguration()

            // Call delegate function and pass in the location of the touch
            DispatchQueue.main.async {
                self.delegate?.mwCamera?(self, didFocusAtPoint: point)
            }
        } catch {
            print("[mwCamera]: Error locking configuration")
        }
    }

    public func zoom(to factor: CGFloat, withRate rate: Float = Float.greatestFiniteMagnitude) {
        guard let videoDevice = captureDevice, !self.isZoomLocked else { return }
        do {
            try videoDevice.lockForConfiguration()
            let previousFactor = videoDevice.videoZoomFactor
            let distance = abs(factor - previousFactor)
            if distance > 1.0 && rate > 0 {
                videoDevice.ramp(toVideoZoomFactor: factor, withRate: rate)
            } else {
                videoDevice.videoZoomFactor = factor
            }
            videoDevice.unlockForConfiguration()

            // Call Delegate function with current zoom scale
            DispatchQueue.main.async {
                self.delegate?.mwCamera?(self, didChangeZoomLevelTo: factor)
            }

        } catch {
            print("[mwCamera]: Error locking configuration")
        }
    }

    /// Freezes the live camera preview layer.
    public func freezePreview() {
        if let previewConnection = self.captureView.videoPreviewLayer.connection {
            previewConnection.isEnabled = false
        }
    }

    /// Un-freezes the live camera preview layer.
    public func unfreezePreview() {
        if let previewConnection = self.captureView.videoPreviewLayer.connection {
            previewConnection.isEnabled = true
        }
    }

    public func flashPreview() {
        self.captureView.videoPreviewLayer.opacity = 0
        UIView.animate(withDuration: 0.35) {
            self.captureView.videoPreviewLayer.opacity = 1
        }
    }
    /// Locks the flash at it's current state.
    public func lockFlash() {
        self.isFlashLocked = true
    }
    /// Unlocks the flash and allows variable states.
    public func unlockFlash() {
        self.isFlashLocked = false
    }
    /// Locks the zoom at it's current scale.
    public func lockZoom() {
        self.isZoomLocked = true
    }
    /// Unlocks the zoom and allows variable change in scale.
    public func unlockZoom() {
        self.isZoomLocked = false
    }
}

extension MWCameraViewController {
    override open func handleSessionWasInterrupted(_ notification: Notification) {
        super.handleSessionWasInterrupted(notification)

        DispatchQueue.main.async { [weak self] in
            if self?.isRecording == true {
                self?.stop()
            }
        }
    }

    override open func handleSessionDidStartRunning(_ notification: Notification) {
        super.handleSessionDidStartRunning(notification)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.captureView.videoPreviewLayer.connection?.videoOrientation = self.orientation
        }
    }
}

internal extension MWCameraViewController {
    override func willBeginRecordingVideo() {
        super.willBeginRecordingVideo()

        //flip video output if front facing camera is selected
        if self.cameraLocation == .front {
            let connection = self.videoOutput?.connection(with: AVMediaType.video)
            if connection?.isVideoMirroringSupported == true {
                connection?.isVideoMirrored = true
            }
        }

        if self.cameraLocation == .back && self.isFlashEnabled {
            self.setFlash(to: .on)
        }

        if self.cameraLocation == .front && self.isFlashEnabled {
            self.addFrontCameraFlashView()
        }

        self.delegate?.mwCamera?(self, willBeginRecordingVideoAt: self.cameraLocation)
    }

    override func didBeginRecordingVideo() {
        super.didBeginRecordingVideo()

        self.startTimer()
        self.delegate?.mwCamera?(self, didBeginRecordingVideoAt: self.cameraLocation)
    }

    override func didFinishRecordingVideo() {
        super.didFinishRecordingVideo()

        if self.flashView?.superview != nil {
            self.removeFrontCameraFlashView()
        }

        if self.captureDevice?.torchMode == .on {
            self.setFlash(to: .off)
        }

        if self.shouldResetZoom {
            self.zoom(to: self.startingZoomScale)
            self.shouldResetZoom = false
        }

        self.delegate?.mwCamera?(self, didFinishRecordingVideoAt: self.cameraLocation)
    }

    override func didFinishProcessingVideoAt(_ url: URL) {
        super.didFinishProcessingVideoAt(url)

        self.delegate?.mwCamera?(self, didFinishProcessingVideoAt: url)
    }

    override func didFailToProcessVideo(_ error: Error) {
        super.didFailToProcessVideo(error)

        self.invalidateTimer()
        self.delegate?.mwCamera?(self, didFailToProcessVideo: error)
    }

    override func didSwitchCamera() {
        super.didSwitchCamera()
        //flip video output if front facing camera is selected
        if self.cameraLocation == .front {
            let connection = self.videoOutput?.connection(with: AVMediaType.video)
            if connection?.isVideoMirroringSupported == true {
                connection?.isVideoMirrored = true
            }
        }

        // Change flash
        if self.isRecording, self.isFlashEnabled {
            if self.cameraLocation == .front {
                self.addFrontCameraFlashView()
            } else if self.cameraLocation == .back {
                self.removeFrontCameraFlashView()
                self.setFlash(to: AVCaptureDevice.TorchMode.on)
            }
        }

        self.delegate?.mwCamera?(self, didSwitchCamera: self.cameraLocation)
    }

    override func didCancelRecording(at url: URL) {
        super.didCancelRecording(at: url)

        if self.flashView?.superview != nil {
            self.removeFrontCameraFlashView()
        }

        if self.captureDevice?.torchMode == .on {
            self.setFlash(to: .off)
        }

        if self.shouldResetZoom {
            self.zoom(to: self.startingZoomScale)
            self.shouldResetZoom = false
        }

        self.delegate?.mwCamera?(self, didCancelRecordingAt: url)
    }

    override func shouldCreateAssetWriter() {
        super.shouldCreateAssetWriter()

        self.delegate?.mwCamera?(shouldCreateAssetWriter: self)
    }

    override func willCaptureImage() {
        super.willCaptureImage()

        //flip video output if front facing camera is selected
        if self.cameraLocation == .front {
            let connection = self.videoOutput?.connection(with: AVMediaType.video)
            if connection?.isVideoMirroringSupported == true {
                connection?.isVideoMirrored = true
            }
        }

        if self.cameraLocation == .back && self.isFlashEnabled {
            self.setFlash(to: .on)
        }

        if self.cameraLocation == .front && self.isFlashEnabled {
            self.addFrontCameraFlashView()
        }

        self.delegate?.mwCamera?(self, willCaptureImageAt: self.cameraLocation)
    }

    override func didCaptureImage() {
        super.didCaptureImage()

        if !self.shouldStartWritingSession {
            if self.flashView?.superview != nil {
                self.removeFrontCameraFlashView()
            }

            if self.captureDevice?.torchMode == .on {
                self.setFlash(to: .off)
            }
        }

        //self.delegate?.mwCamera?(self, didCaptureImageAt: self.cameraLocation)
    }

    override func didFinishProcessing(image: UIImage, with properties: CFDictionary) {
        super.didFinishProcessing(image: image, with: properties)

        self.delegate?.mwCamera?(self, didFinishProcessing: image, with: properties)
    }
}

extension MWCameraViewController {
    private func setFlash(to torchMode: AVCaptureDevice.TorchMode) {
        guard let device = self.captureDevice,
            device.hasTorch, !self.isFlashLocked else { return }
        DispatchQueue.main.async {
            do {
                try device.lockForConfiguration()
                device.torchMode = torchMode
                device.unlockForConfiguration()
            } catch {
                print("[mwCamera]: Could not configure device Torch: \(error)")
            }
        }
    }

    private func addFrontCameraFlashView() {
        guard flashView == nil, !self.isFlashLocked else { return }
        flashView = UIView(frame: view.frame)
        flashView?.backgroundColor = UIColor.white
        flashView?.alpha = 0.65
        captureView.addSubview(flashView!)
        self.previousScreenBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 1.0
    }

    private func removeFrontCameraFlashView() {
        guard flashView != nil, !self.isFlashLocked else { return }
        let previousScreenBrightness = self.previousScreenBrightness
        UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveEaseInOut, animations: { [weak self] in
            self?.flashView?.alpha = 0.0
            UIScreen.main.brightness = previousScreenBrightness
        }, completion: { [weak self] (_) in
            self?.flashView?.removeFromSuperview()
            self?.flashView = nil
        })
    }
}

extension MWCameraViewController {
    @objc private func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard isSessionRunning else { return }
        guard let videoDevice = captureDevice else { return }
        switch sender.state {
        case .began:
            startingZoomScale = videoDevice.videoZoomFactor
            fallthrough
        case .changed, .ended:
            let scale = min(maxZoomScale, max(minZoomScale, startingZoomScale * sender.scale))
            let adjustedScale = min(videoDevice.activeFormat.videoMaxZoomFactor, max(1.0, scale))
            zoom(to: adjustedScale)
        default: break
        }
    }

    @objc private func handleSingleTap(_ sender: UITapGestureRecognizer) {
        guard isSessionRunning && sender.state == .recognized else { return }
        let tapPoint = sender.location(in: captureView)
        self.focus(at: tapPoint)
    }

    @objc private func doubleTapGesture(_ sender: UITapGestureRecognizer) {
        guard isSessionRunning && sender.state == .recognized else { return }
        self.switchCamera()
    }

    private func addGestureRecognizers() {
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGestureRecognizer.delegate = self
        view.addGestureRecognizer(pinchGestureRecognizer)

        singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTapGestureRecognizer.numberOfTapsRequired = 1
        singleTapGestureRecognizer.delegate = self
        view.addGestureRecognizer(singleTapGestureRecognizer)

        doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTapGesture(_:)))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        doubleTapGestureRecognizer.delegate = self
        view.addGestureRecognizer(doubleTapGestureRecognizer)

        singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
    }

}
// Button related stuff
extension MWCameraViewController {
    public func register(_ button: MWCameraButton) {
        let longPressGestureRecognizer = LongPressGestureRecognizer()
        longPressGestureRecognizer.addTarget(self, action: #selector(handleButtonZoomPan(_:)))
        longPressGestureRecognizer.addTarget(self, action: #selector(handleButtonLongPress(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.0
        longPressGestureRecognizer.delegate = self
        button.addGestureRecognizer(longPressGestureRecognizer)
        button.longPressGestureRecognizer = longPressGestureRecognizer
    }
    // Please Keep in mind that this function is called first by the gesture recognizer
    @objc private func handleButtonZoomPan(_ sender: LongPressGestureRecognizer) {
        guard self.isPanToZoomEnabled else { return }
        guard self.isSessionRunning, let videoDevice = self.captureDevice else { return }

        switch sender.state {
        case .began:
            if !self.isRecording {
                self.startingZoomScale = videoDevice.videoZoomFactor
                self.shouldResetZoom = true
            }
            fallthrough
        case .changed, .ended:
            guard !self.shouldIgnore else { return }

            let location = sender.location(in: sender.view)

            if location.y >= 0 {
                sender.setTranslation(.zero, in: nil)
            }

            let translation = sender.translation(in: nil)
            let mulitiplier: CGFloat = min(max(1.0, self.maxZoomScale), videoDevice.activeFormat.videoMaxZoomFactor)
            let senderScale = (-1 * translation.y / self.zoomPanMaxLength ) * mulitiplier//+ 1.0
            let scale = min(self.maxZoomScale, max(self.minZoomScale, self.startingZoomScale * senderScale))
            let adjustedScale = min(videoDevice.activeFormat.videoMaxZoomFactor, max(1.0, scale))
            self.zoom(to: adjustedScale)
        case .cancelled:
            if self.shouldResetZoom {
                self.zoom(to: self.startingZoomScale, withRate: -1)
                self.shouldResetZoom = false
            }
        default: break
        }
    }

    // Please Keep in mind that this function is called second by the gesture recognizer
    @objc fileprivate func handleButtonLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            if !self.shouldStartWritingSession {
                self.start()
            } else {
                self.shouldStop = true
            }
        case .ended:
            guard !self.shouldIgnore else {
                self.shouldIgnore = false
                return
            }

            if self.timePassed <= self.photoCaptureThreshold {
                // Take photo and discard Video
                self.capturePhoto()

                let shouldUnlockFlash = self.isFlashLocked == false
                let shouldUnlockZoom = self.isZoomLocked == false
                self.lockFlash()
                self.lockZoom()

                self.cancel()

                self.executeAsync {
                    DispatchQueue.main.async { [weak self] in
                        if shouldUnlockFlash {
                            self?.unlockFlash()
                        }
                        if shouldUnlockZoom {
                            self?.unlockZoom()
                        }
                    }
                }
            } else if self.stopsRecordingOnTouchUp && self.isRecording {
                self.stop()
            } else if self.shouldStop {
                self.stop()
                self.shouldStop = false
            }
        case .cancelled:
            guard !self.shouldIgnore else {
                self.shouldIgnore = false
                return
            }
            self.cancel()
        default:
            break
        }
    }

    private func start() {
        self.shouldCreateTimer = true
        self.startRecording()
    }

    private func stop() {
        self.shouldCreateTimer = false
        self.invalidateTimer()
        self.stopRecording()
    }

    private func cancel() {
        self.shouldCreateTimer = false
        self.invalidateTimer()
        self.cancelRecording()
    }

    @objc private func updateTimer() {
        self.timePassed += 0.1
        delegate?.mwCamera?(self, didUpdateRecordingDurationTo: self.timePassed)

        if timePassed >= maximumVideoDuration {
            DispatchQueue.main.async { [weak self] in
                self?.shouldIgnore = true
                self?.stop()
            }
        }
    }

    private func startTimer() {
        guard self.shouldCreateTimer else { return }
        self.timer = Timer.scheduledTimer(
            timeInterval: self.videoTimeInterval, target: self,
            selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }

    private func invalidateTimer() {
        self.timer?.invalidate()
        self.timer = nil
        self.timePassed = 0.0
        delegate?.mwCamera?(self, didUpdateRecordingDurationTo: self.timePassed)
    }
}

extension MWCameraViewController: UIGestureRecognizerDelegate {
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == pinchGestureRecognizer {
            return isPinchToZoomEnabled
        }

        if gestureRecognizer == singleTapGestureRecognizer {
            return isTapToFocusEnabled
        }

        if gestureRecognizer == doubleTapGestureRecognizer {
            return isDoubleTapToSwitchCameraEnabled
        }

        if gestureRecognizer is UILongPressGestureRecognizer && gestureRecognizer.view is MWCameraButton {
            return true
        }

        return false
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        return false
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return true
    }

    open func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    open func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    open func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

private class LongPressGestureRecognizer: UILongPressGestureRecognizer {
    override var state: UIGestureRecognizer.State {
        didSet {
            if state == .began {
                self.startingLocation = self.location(in: self.view)
            }
        }
    }

    var startingLocation: CGPoint = .zero

    func translation(in view: UIView?) -> CGPoint {
        let startingLocation = self.view?.convert(self.startingLocation, to: view) ?? self.startingLocation
        let currentLocation = self.location(in: view)
        return CGPoint(x: currentLocation.x - startingLocation.x, y: currentLocation.y - startingLocation.y)
    }

    func setTranslation(_ translation: CGPoint, in view: UIView?) {
        self.startingLocation = self.location(in: self.view)
    }
}
