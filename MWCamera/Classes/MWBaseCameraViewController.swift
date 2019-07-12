//
//  MWBaseCameraViewController.swift
//  MWCamera
//
//  Created by Woody Jean-Louis on 5/14/19.
//

import UIKit
import AVFoundation

public typealias MWCamera = MWBaseCameraViewController
public typealias MWCameraLocation = AVCaptureDevice.Position

open class MWBaseCameraViewController: UIViewController {
    // MARK: Private Declarations
    private let sessionPrimaryQueueIdentifier = "mwCamera_sessionPrimaryQueue"
    private let sessionPrimaryQueueSpecificKey = DispatchSpecificKey<()>()
    // Serial queue used for setting up session
    private var sessionPrimaryQueue: DispatchQueue
    //
    private let sessionSecondaryQueueIdentifier = "mwCamera_sessionSecondaryQueue"
    private let sessionSecondaryQueueSpecificKey = DispatchSpecificKey<()>()
    // Serial queue used for setting up session
    private var sessionSecondaryQueue: DispatchQueue
    // Variable
    private var lastZoomScale = CGFloat(1.0)
    //
    private var isSwitchingCameras = false
    // BackgroundID variable for video recording
    private var backgroundTaskID: UIBackgroundTaskIdentifier.RawValue.IntegerLiteralType?
    //
    private var didStartWritingSession = false
    //
    private var systemObserver: NSKeyValueObservation?
    //
    private var assetWriterInputPixelBufferAdator: AVAssetWriterInputPixelBufferAdaptor?
    //
    private var previousPresentationTimeStamp: CMTime = .zero
    //
    private var startingPresentationTimeStamp: CMTime = .zero
    //
    private var frameRate: Int = 0
    //
    private var frameCount = 0
    //
    private var shouldCapturePhotoFromDataOutput = false
    //
    private var willStartWritingSession = false
    //
    private(set) internal var shouldStartWritingSession = false
    //

    // Returns the current camera being used.
    private(set) public var cameraLocation = AVCaptureDevice.Position.back
    //
    private(set) public var recordingDuration: Double = 0.0
    // Video Device variable
    private(set) public var captureDevice: AVCaptureDevice?
    // PreviewView for the capture session
    private(set) var captureView = MWCameraView()

    // Current Capture Session
    internal let session = AVCaptureSession()

    // MARK: Public Declarations

    public var videoInput: AVCaptureDeviceInput?
    public var videoOutput: AVCaptureVideoDataOutput?
    public var audioInput: AVCaptureDeviceInput?
    public var audioOutput: AVCaptureAudioDataOutput?

    public var assetWriter: AVAssetWriter?
    public var assetWriterVideoInput: AVAssetWriterInput?
    public var assetWriterAudioInput: AVAssetWriterInput?
    // Video capture quality
    public var videoQuality = AVCaptureSession.Preset.high
    //
    public var orientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            captureView.videoPreviewLayer.connection?.videoOrientation = self.orientation
            let connection = self.videoOutput?.connection(with: AVMediaType.video)
            if connection?.isVideoOrientationSupported == true {
                connection?.videoOrientation = self.orientation
            }
        }
    }
    /// Sets default camera location on initial start
    public var defaultCameraLocation = AVCaptureDevice.Position.back {
        didSet {
            if !isSessionRunning {
                self.cameraLocation = self.defaultCameraLocation
            }
        }
    }
    //
    public var captureDeviceType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
    // Sets whether or not video recordings will record audio
    public var isAudioEnabled = true
    /// Returns true if the capture session is currently running
    public var isSessionRunning: Bool { return session.isRunning }
    // Directory used for uploading files Directoy
    public var outputFileDirectory: URL = FileManager.default.temporaryDirectory
    /// Desired number of frame per secon. MWCamera will adjust the frame rate only when system is under pressure.
    public var desiredFrameRate: Int = 30 {
        didSet {
            self.configureFrameRate()
        }
    }
    // Returns true if video is currently being recorded
    public var isRecording: Bool {
        return self.didStartWritingSession
    }
    // allow background audio from other applications to continue playing during capture
    public var allowsBackgroundAudio = true

    public init() {
        self.sessionPrimaryQueue = DispatchQueue(
                label: self.sessionPrimaryQueueIdentifier, qos: .userInitiated, target: DispatchQueue.global())
        self.sessionSecondaryQueue = DispatchQueue(
            label: self.sessionSecondaryQueueIdentifier, qos: .utility, target: DispatchQueue.global())

        super.init(nibName: nil, bundle: nil)

        self.addApplicationObservers()
        self.addSessionObservers()
        self.addSystemObervers()

        self.sessionPrimaryQueue.setSpecific(key: self.sessionPrimaryQueueSpecificKey, value: ())
        self.sessionSecondaryQueue.setSpecific(key: self.sessionSecondaryQueueSpecificKey, value: ())

        self.session.automaticallyConfiguresApplicationAudioSession = false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if self.session.isRunning {
            self.session.stopRunning()
        }
        removeApplicationObservers()
        removeSessionObservers()
        removeSystemObservers()
    }
}

extension MWBaseCameraViewController {
    private func configureSessionQuality() {
        let preset = self.videoQuality
        guard self.session.canSetSessionPreset(preset) else {
            print(
                "[mwCamera]: Error could not set session preset to \(preset), which enables custom video quality control. Defaulting to \(session.sessionPreset)")
            return
        }
        session.sessionPreset = preset

        self.configureFrameRate()
    }
    /// Fixing framerate does effect low light capture performance
    /// Todo: Make this functionality optional.
    private func configureFrameRate(toframeRate: Int? = nil) {
        guard let videoDevice = captureDevice else {
            print("[mwCamera]: Cannot configure frame rate. Reason: Capture Device is nil")
            return
        }

        let desiredFrameRate = toframeRate ?? self.desiredFrameRate
        var frameRate: Int = desiredFrameRate

        let ranges = videoDevice.activeFormat.videoSupportedFrameRateRanges

        let maxFrameRates = ranges.map({ return $0.maxFrameRate })

        let minFrameRates = ranges.map({ return $0.minFrameRate })

        var maxFrameRate = -1
        var minFrameRate = -1

        maxFrameRates.forEach { (rate) in
            maxFrameRate = rate > Double(maxFrameRate) ? Int(rate) : maxFrameRate
        }

        minFrameRates.forEach { (rate) in
            minFrameRate = rate > Double(minFrameRate) ? Int(rate) : minFrameRate
        }

        if desiredFrameRate > maxFrameRate {
            print(
                "[mwCamera]: Desired frame rate is higher than supported frame rates. setting to \(maxFrameRate) instead.")
            frameRate = maxFrameRate
        } else if desiredFrameRate < minFrameRate {
            print(
                "[mwCamera]: Desired frame rate is lower than supported frame rates. setting to \(minFrameRate) instead.")
            frameRate = minFrameRate
        }

        guard videoDevice.activeVideoMinFrameDuration.timescale != frameRate,
            videoDevice.activeVideoMaxFrameDuration.timescale != frameRate else { return }

        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeVideoMinFrameDuration = CMTime.init(value: 1, timescale: CMTimeScale(frameRate))
            videoDevice.activeVideoMaxFrameDuration = CMTime.init(value: 1, timescale: CMTimeScale(frameRate))
            videoDevice.unlockForConfiguration()

            self.frameRate = frameRate
        } catch {
            print("[mwCamera]: Could not lock device for configuration: \(error)")
        }
    }

    private func addVideoInput() {
        self.captureDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [captureDeviceType], mediaType: AVMediaType.video, position: cameraLocation).devices.first

        self.removeSystemObservers()
        self.addSystemObervers()

        guard let videoDevice = self.captureDevice else {
            print("[mwCamera]: Could not add video device input to the session")
            return
        }

        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
                self.videoInput = videoDeviceInput
            } else {
                print("[mwCamera]: Could not add video device input to the session")
            }
        } catch {
            print("[mwCamera]: Could not create video device input: \(error)")
        }
    }

    private func addVideoOutput() {
        let dataOutput = AVCaptureVideoDataOutput.init()
        dataOutput.setSampleBufferDelegate(self, queue: self.sessionSecondaryQueue)

        if self.session.canAddOutput(dataOutput) {
            self.session.addOutput(dataOutput)
        }

        let connection = dataOutput.connection(with: AVMediaType.video)
        if connection?.isVideoOrientationSupported == true {
            connection?.videoOrientation = self.orientation
        }

        self.videoOutput = dataOutput
    }

    private func addAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio) else {
            print("[mwCamera]: Could not add audio device input to the session")
            return
        }
        do {
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if self.session.canAddInput(audioDeviceInput) {
                self.session.addInput(audioDeviceInput)
                self.audioInput = audioDeviceInput
            } else {
                print("[mwCamera]: Could not add audio device input to the session")
            }
        } catch {
            print("[mwCamera]: Could not create audio device input: \(error)")
        }
    }

    private func addAudioOutput() {
        let dataOutput = AVCaptureAudioDataOutput.init()
        dataOutput.setSampleBufferDelegate(self, queue: self.sessionSecondaryQueue)

        if self.session.canAddOutput(dataOutput) {
            self.session.addOutput(dataOutput)
            self.audioOutput = dataOutput
        }
    }

    private func removeAudioOutput() {
        guard let audioOutput = self.audioOutput else { return }
        self.session.removeOutput(audioOutput)
        self.audioOutput = nil
    }

    private func removeAudioInput() {
        guard let audioInput = self.audioInput else { return }
        self.session.removeInput(audioInput)
        self.audioInput = nil
    }
}

extension MWBaseCameraViewController {
    @objc open func setPreviousBackgroundAudioPreference() {}

    private func setBackgroundAudioPreference() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            var options: AVAudioSession.CategoryOptions = AVAudioSession.CategoryOptions.init()

            if audioSession.isOtherAudioPlaying && self.allowsBackgroundAudio {
                options.insert(.mixWithOthers)
                try audioSession.setActive(false)
            }

            try audioSession.setCategory(
                AVAudioSession.Category.playAndRecord,
                mode: AVAudioSession.Mode.videoRecording, options: options)
            try audioSession.setActive(true)

        } catch {
            print("[mwCamera]: Failed to set background audio preference \(error.localizedDescription)")
        }
    }
}

@objc public extension MWBaseCameraViewController {
    // MARK: Public Functions
    /// Starts the AVCaptureSession.
    func beginSession() {
        self.session.startRunning()
    }

    func endSession() {
        self.session.stopRunning()
    }

    func reconfigureSession() {
        self.executeSync { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()

            for input in self.session.inputs {
                self.session.removeInput(input)
            }

            self.addVideoInput()
            self.addVideoOutput()
//            self.addAudioInput()
            self.addAudioOutput()

            self.configureSessionQuality()

            self.session.commitConfiguration()
        }
    }
    /// Starts a new recording.
    func startRecording() {
        assert(Thread.isMainThread, "[mwCamera]: This function -startRecording must be called on the main thread.")

        self.executeAsync { [weak self] in
            guard let self = self else { return  }
            assert(
                !self.willStartWritingSession && !self.shouldStartWritingSession,
                "[mwCamera]: Called startRecording() when already recording.")
            self.willStartWritingSession = true

            self.shouldCreateAssetWriter()

            let uuid = UUID().uuidString
            let fileType = self.assetWriter?.outputFileType ?? AVFileType.mov
            assert(fileType.isVideoFileTypeSupported, "fileType is not supported for video")
            let outputFileName = (uuid as NSString).appendingPathExtension(fileType.stringValue())!
            let outputFileUrl = self.outputFileDirectory.appendingPathComponent(outputFileName, isDirectory: false)
            do {
                let assetWriter = try self.assetWriter ?? AVAssetWriter(outputURL: outputFileUrl, fileType: fileType)
                self.assetWriter = assetWriter
            } catch {
                print("[mwCamera]: error setting up avassetwrtter: \(error)")
                return
            }

            guard let assetWriter = self.assetWriter else { fatalError("asset writer is nil") }

            self.setBackgroundAudioPreference()
            // Adding audio her is necessary to mimic Snapchat/Instagram camera
            //self.session.beginConfiguration()
            self.addAudioInput()
            //self.addAudioOutput()
            //self.session.commitConfiguration()

            var videoCompressionSettings = self.videoOutput?.recommendedVideoSettingsForAssetWriter(
                writingTo: assetWriter.outputFileType)
            var compressionProperties = videoCompressionSettings?[AVVideoCompressionPropertiesKey] as? [String: Any]
            compressionProperties?[AVVideoExpectedSourceFrameRateKey] = self.frameRate
            videoCompressionSettings?[AVVideoCompressionPropertiesKey] = compressionProperties
            let assetWriterVideoInput = self.assetWriterVideoInput ?? AVAssetWriterInput(
                mediaType: AVMediaType.video, outputSettings: videoCompressionSettings)
            assetWriterVideoInput.expectsMediaDataInRealTime = true

            if assetWriter.canAdd(assetWriterVideoInput) {
                assetWriter.add(assetWriterVideoInput)
            } else {
                print("[mwCamera]: Could not add VideoWriterInput to VideoWriter")
            }

            self.assetWriterVideoInput = assetWriterVideoInput

            if self.isAudioEnabled {
                let audioCompressionSettings = self.audioOutput?.recommendedAudioSettingsForAssetWriter(
                    writingTo: assetWriter.outputFileType) as? [String: Any]
                let assetWriterAudioInput = self.assetWriterAudioInput ?? AVAssetWriterInput(
                    mediaType: AVMediaType.audio, outputSettings: audioCompressionSettings)
                assetWriterAudioInput.expectsMediaDataInRealTime = true
                if assetWriter.canAdd(assetWriterAudioInput) {
                    assetWriter.add(assetWriterAudioInput)
                } else {
                    print("[mwCamera]: Could not add AudioWriterInput to VideoWriter")
                }
                self.assetWriterAudioInput = assetWriterAudioInput
            }

            self.assetWriterInputPixelBufferAdator = AVAssetWriterInputPixelBufferAdaptor.init(
                assetWriterInput: assetWriterVideoInput, sourcePixelBufferAttributes: nil)

            assetWriter.startWriting()

            DispatchQueue.main.async {
                self.willBeginRecordingVideo()
            }

            self.shouldStartWritingSession = true
            self.willStartWritingSession = false
        }
    }
    /// Finishes the Recording.
    func stopRecording() {
        assert(Thread.isMainThread, "[mwCamera]: This function -stopRecording must be called on the main thread.")

        self.executeAsync { [weak self] in
            guard let self = self else { return }
            assert(
                self.shouldStartWritingSession, "[mwCamera]: Called stopRecording() while video is not being recorded")
            guard let assetWriter = self.assetWriter else { return }
            self.shouldStartWritingSession = false
            self.didStartWritingSession = false
            self.frameCount = 0
            self.recordingDuration = 0.0

            self.assetWriterVideoInput?.markAsFinished()
            self.assetWriterAudioInput?.markAsFinished()
            // Must remove audio after recording in order to mimic Snapchat/Instagram camera
            //self.session.beginConfiguration()
            self.removeAudioInput()
            //self.removeAudioOutput()
            //self.session.commitConfiguration()
            self.setPreviousBackgroundAudioPreference()

            DispatchQueue.main.async {
                self.didFinishRecordingVideo()
            }

            assetWriter.finishWriting {
                DispatchQueue.main.async {
                    if let error = assetWriter.error {
                        self.didFailToProcessVideo(error)
                    } else {
                        self.didFinishProcessingVideoAt(assetWriter.outputURL)
                    }
                }
            }

            self.assetWriter = nil
            self.assetWriterAudioInput = nil
            self.assetWriterVideoInput = nil
        }
    }
    /// Cancels the current recording and deletes the file.
    func cancelRecording() {
        assert(Thread.isMainThread, "[mwCamera]: This function -cancelRecording must be called on the main thread.")

        self.executeAsync { [weak self] in
            guard let self = self else { return }
            assert(
                self.shouldStartWritingSession, "[mwCamera]: Called cancelRecording() while video is not being recorded")
            guard let assetWriter = self.assetWriter else { return }
            self.shouldStartWritingSession = false
            self.didStartWritingSession = false
            self.frameCount = 0
            self.recordingDuration = 0.0

            let url = assetWriter.outputURL

            assetWriter.cancelWriting()

            // Must remove audio after recording in order to mimic Snapchat/Instagram camera
            //self.session.beginConfiguration()
            self.removeAudioInput()
            //self.removeAudioOutput()
            //self.session.commitConfiguration()
            self.setPreviousBackgroundAudioPreference()

            DispatchQueue.main.async {
                self.didCancelRecording(at: url)
            }

            self.assetWriter = nil
            self.assetWriterAudioInput = nil
            self.assetWriterVideoInput = nil
        }
    }
    /// Caputures a photo using AVCaptureVideoDataOutput after the specified number of seconds. defaults to right now.
    func capturePhoto(after deadline: TimeInterval = 0) {

        if Thread.isMainThread {
            self.willCaptureImage()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.willCaptureImage()
            }
        }

        executeAsync {
            Thread.sleep(forTimeInterval: deadline)
            self.shouldCapturePhotoFromDataOutput = true
        }
    }
    /// Switches the camera from front to back and vice versa.
    func switchCamera() {
        guard isSessionRunning && !isSwitchingCameras else { return }
        self.isSwitchingCameras = true
        let zoomScale = lastZoomScale

        executeSync { [weak self] in
            guard let self = self else { return }
            self.lastZoomScale = self.captureDevice?.videoZoomFactor ?? 1.0

            self.cameraLocation = self.cameraLocation.opposite()

            self.session.beginConfiguration()

            if let videoInput = self.videoInput {
                self.session.removeInput(videoInput)
            }

            self.addVideoInput()
            self.configureSessionQuality()

            // Fix initial frame having incorrect orientation
            let connection = self.videoOutput?.connection(with: .video)
            if connection?.isVideoOrientationSupported == true {
                connection?.videoOrientation = self.orientation
            }

            DispatchQueue.main.async {
                self.didSwitchCamera()
            }

            self.session.commitConfiguration()

            do {
                try self.captureDevice?.lockForConfiguration()
                self.captureDevice?.videoZoomFactor = zoomScale
                self.captureDevice?.unlockForConfiguration()
            } catch {
                print("[mwCamera]: Error locking configuration")
            }

            self.isSwitchingCameras = false
        }
    }
}

@objc internal extension MWBaseCameraViewController {
    //
    func shouldCreateAssetWriter() {

    }
    ///
    func willBeginRecordingVideo() {
        if UIDevice.current.isMultitaskingSupported {
            let backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
                // End Task
                if self?.isRecording == true {
                    self?.stopRecording()
                }
            }
            self.backgroundTaskID = backgroundTaskID.rawValue
        }
    }
    ///
    func didBeginRecordingVideo() {

    }
    ///
    func didFinishRecordingVideo() {

    }
    ///
    func didFinishProcessingVideoAt(_ url: URL) {
        if let currentBackgroundTaskID = backgroundTaskID {
            backgroundTaskID = UIBackgroundTaskIdentifier.invalid.rawValue

            if currentBackgroundTaskID != UIBackgroundTaskIdentifier.invalid.rawValue {
                UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: currentBackgroundTaskID))
            }
        }
    }
    ///
    func didFailToProcessVideo(_ error: Error) {
        if let currentBackgroundTaskID = backgroundTaskID {
            backgroundTaskID = UIBackgroundTaskIdentifier.invalid.rawValue

            if currentBackgroundTaskID != UIBackgroundTaskIdentifier.invalid.rawValue {
                UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: currentBackgroundTaskID))
            }
        }
    }
    ///
    func didSwitchCamera() {

    }
    ///
    func didCancelRecording(at url: URL) {

    }
    ///
    func willCaptureImage() {

    }
    ///
    func didCaptureImage() {

    }
    ///
    func didFinishProcessing(image: UIImage, with properties: CFDictionary) {

    }
}

extension MWBaseCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        print("[mwCamera]: Dropped \(output == self.audioOutput ? "audio" : "video") Frame")
    }

    public func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        if self.shouldCapturePhotoFromDataOutput {
            self.shouldCapturePhotoFromDataOutput = false

            self.handlePhotoCapture(sampleBuffer)
        }

        guard self.shouldStartWritingSession else { return }

        let isDataReady = CMSampleBufferDataIsReady(sampleBuffer)
        guard isDataReady, let assetWriter = self.assetWriter else { return }

        if !self.didStartWritingSession {
            let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSession(atSourceTime: presentationTimestamp)
            self.didStartWritingSession = true
            DispatchQueue.main.async {
                self.didBeginRecordingVideo()
            }
            self.startingPresentationTimeStamp = presentationTimestamp
            self.previousPresentationTimeStamp = presentationTimestamp
        }

        guard self.isRecording else { return }

        if output == self.audioOutput {
            self.handleAudioBuffer(sampleBuffer)
        }

        if output == self.videoOutput {
            self.handleVideoBuffer(sampleBuffer)
        }
    }

    private func handlePhotoCapture(_ sampleBuffer: CMSampleBuffer) {
        let isDataReady = CMSampleBufferDataIsReady(sampleBuffer)
        guard isDataReady else {
            print("[mwCamera]: SampleBuffer was not ready")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.didCaptureImage()
        }

        guard let cgImage = self.cgImage(from: sampleBuffer) else { return }
        let size = UIScreen.main.bounds.size
        guard let image = UIImage.init(cgImage: cgImage).scaled(toHeight: size.height) else { return }
        let properties = metadata(from: sampleBuffer)

        DispatchQueue.main.async { [weak self] in
            self?.didFinishProcessing(image: image, with: properties)
        }
    }

    private func handleAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let assetWriter = self.assetWriter else { return }
        if let assetWriterAudioInput = self.assetWriterAudioInput,
            assetWriterAudioInput.isReadyForMoreMediaData {
            let success = assetWriterAudioInput.append(sampleBuffer)
            if !success, let error = assetWriter.error {
                print(error)
                fatalError(error.localizedDescription)
            }
        }
    }

    private func handleVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let assetWriter = self.assetWriter else { return }
        if let assetWriterInputPixelBufferAdator = self.assetWriterInputPixelBufferAdator,
            let assetWriterVideoInput = self.assetWriterVideoInput,
            assetWriterVideoInput.isReadyForMoreMediaData,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

            let currentPresentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let previousPresentationTimeStamp = self.previousPresentationTimeStamp

            // Frame correction logic. Fixes the bug of video/audio unsynced when switching cameras
            let currentFramePosition =
                (Double(self.frameRate) * Double(currentPresentationTimestamp.value))
                    / Double(currentPresentationTimestamp.timescale)
            let previousFramePosition =
                (Double(self.frameRate) * Double(previousPresentationTimeStamp.value))
                    / Double(previousPresentationTimeStamp.timescale)
            var presentationTimeStamp = currentPresentationTimestamp
            let maxFrameDistance = 1.1
            let frameDistance = currentFramePosition - previousFramePosition
            if frameDistance > maxFrameDistance {
                let expectedFramePosition = previousFramePosition + 1.0
//                print(
//                    "[mwCamera]: Frame at incorrect position moving from \(currentFramePosition) to \(expectedFramePosition)")
                let newFramePosition =
                    (expectedFramePosition * Double(currentPresentationTimestamp.timescale)) / Double(self.frameRate)

                let newPresentationTimeStamp = CMTime.init(
                    value: CMTimeValue(newFramePosition), timescale: currentPresentationTimestamp.timescale)

                presentationTimeStamp = newPresentationTimeStamp
            }

            let success = assetWriterInputPixelBufferAdator.append(
                pixelBuffer, withPresentationTime: presentationTimeStamp)
            if !success, let error = assetWriter.error {
                print(error)
                fatalError(error.localizedDescription)
            }

            self.previousPresentationTimeStamp = presentationTimeStamp

            let startTime =
                Double(startingPresentationTimeStamp.value) / Double(startingPresentationTimeStamp.timescale)
            let currentTime =
                Double(currentPresentationTimestamp.value) / Double(currentPresentationTimestamp.timescale)
            let previousTime =
                Double(previousPresentationTimeStamp.value) / Double(previousPresentationTimeStamp.timescale)

            self.frameCount += 1
            self.recordingDuration = currentTime - startTime

            if (Int(previousTime - startTime) == Int(currentTime - startTime)) == false {
                //print("[mwCamera]: Frame Count for previous second: \(self.frameCount)")
                self.frameCount = 0
            }
        }
    }
}

extension MWBaseCameraViewController {
    private func cgImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        let ciImage = CIImage.init(cvPixelBuffer: pixelBuffer)
        let context = CIContext.init()
        let cgimage = context.createCGImage(ciImage, from: ciImage.extent)
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        return cgimage
    }

    private func metadata(from sampleBuffer: CMSampleBuffer) -> NSMutableDictionary {
        let rawMetadata = CMCopyDictionaryOfAttachments(
            allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        return metadata
    }

    private func metadata(from url: URL) {
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
            if let dict = imageProperties as? [String: Any] {
                print(dict)
            }

            guard let imageMetadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, .none) else {
                return
            }

            guard let tags = CGImageMetadataCopyTags(imageMetadata) else {
                return
            }
            // swiftlint:disable force_cast
            var result = [String: Any]()
            for tag in tags as NSArray {
                let tagMetadata = tag as! CGImageMetadataTag
                if let cfName = CGImageMetadataTagCopyName(tagMetadata) {
                    let name = String(cfName)
                    let value = CGImageMetadataTagCopyValue(tagMetadata)
                    result[name] = value
                }
            }

            // swiftlint:enable force_cast

            print(result)
        }
    }
    public func createData(
        from cgImage: CGImage, fileType: AVFileType, quality: CGFloat,
        properties: NSMutableDictionary = NSMutableDictionary()) -> Data? {

        let imageData = NSMutableData()
        let numberOfImages = 1
        guard let destination = CGImageDestinationCreateWithData(
            imageData as CFMutableData, fileType as CFString, numberOfImages, nil) else { return nil }

        let options = [kCGImageDestinationLossyCompressionQuality: quality]
        properties.addEntries(from: options)
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        CGImageDestinationFinalize(destination)

        return imageData as Data
    }

    public func save(
        cgImage: CGImage, fileType: AVFileType, quality: CGFloat,
        properties: NSMutableDictionary = NSMutableDictionary()) -> URL? {

        let uuid = UUID().uuidString
        assert(fileType.isImageFileTypeSupported, "fileType is not supported for video")
        let outputFileName = (uuid as NSString).appendingPathExtension(fileType.stringValue())!
        let outputFileUrl = self.outputFileDirectory.appendingPathComponent(outputFileName, isDirectory: false)

        //var qual = quality
        //let compression = CFNumberCreate(kCFAllocatorDefault, CFNumberType.floatType, &qual)
        let numberOfImages = 1
        guard let destination = CGImageDestinationCreateWithURL(
            outputFileUrl as CFURL, fileType as CFString, numberOfImages, nil)
            else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality]
        properties.addEntries(from: options)
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }

        return outputFileUrl
    }
}

private extension UIImage {
    func scaled(toWidth width: CGFloat) -> UIImage? {
        let oldWidth = self.size.width
        let scaleFactor = width / oldWidth
        let newHeight = self.size.height * scaleFactor
        let newWidth = oldWidth * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { _ in
            self.draw(in: CGRect.init(origin: CGPoint.zero, size: newSize))
        }
        return newImage
    }

    func scaled(toHeight height: CGFloat) -> UIImage? {
        let scale = height / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: height)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { _ in
            self.draw(in: CGRect.init(origin: CGPoint.zero, size: newSize))
        }

        return newImage
    }
}

extension MWBaseCameraViewController {
    private func addApplicationObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleApplicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleApplicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func removeApplicationObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func addSessionObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSessionRuntimeError(_:)),
            name: NSNotification.Name.AVCaptureSessionRuntimeError, object: self.session)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSessionWasInterrupted(_:)),
            name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: self.session)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSessionInterruptionEnded(_:)),
            name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: self.session)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSessionDidStartRunning(_:)),
            name: NSNotification.Name.AVCaptureSessionDidStartRunning, object: self.session)
    }

    private func removeSessionObservers() {
        NotificationCenter.default.removeObserver(
            self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: self.session)
        NotificationCenter.default.removeObserver(
            self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: self.session)
        NotificationCenter.default.removeObserver(
            self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: self.session)
        NotificationCenter.default.removeObserver(
            self, name: NSNotification.Name.AVCaptureSessionDidStartRunning, object: self.session)
    }

    private func addSystemObervers() {
        guard let videoDevice = self.captureDevice else { return }
        systemObserver = videoDevice.observe(
        \AVCaptureDevice.systemPressureState, options: [.new]) { [weak self] (_, change) in
            guard let self = self else { return }
            guard let systemPressureState = change.newValue else { return }
            let pressureLevel = systemPressureState.level
            switch pressureLevel {
            case .serious, .critical:
                if self.isRecording {
                    print(
                        "[mwCamera]: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                    self.configureFrameRate(toframeRate: 20)
                }
            case .shutdown:
                print("[mwCamera]: Session stopped running due to shutdown system pressure level.")
            default:
                if self.isRecording {
                    print(
                        "[mwCamera]: Reached normal system pressure level: \(pressureLevel). Resetting frame rate.")
                    self.configureFrameRate()
                }
            }
        }
    }

    private func removeSystemObservers() {
        systemObserver = nil
    }

    @objc open func handleApplicationWillResignActive(_ notification: Notification) {

    }

    @objc open func handleApplicationDidBecomeActive(_ notification: Notification) {

    }

    @objc open func handleSessionRuntimeError(_ notification: Notification) {
        print("[mwCamera]: SessionRuntimeError: \(String(describing: notification.userInfo))")
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            switch error.code {
            case .deviceIsNotAvailableInBackground:
                print("Media services are not available in the background")
            case .mediaServicesWereReset:
                print("Media services were reset")
                //self.session.startRunning()
            default:
                break
            }
        }
    }

    @objc open func handleSessionWasInterrupted(_ notification: Notification) {

    }

    @objc open func handleSessionInterruptionEnded(_ notification: Notification) {

    }

    @objc open func handleSessionDidStartRunning(_ notification: Notification) {

    }
}

extension MWBaseCameraViewController {
    func executeAsync(_ closure: @escaping () -> Void) {
        self.sessionPrimaryQueue.async(execute: closure)
    }

    func executeSync(withClosure closure: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: self.sessionPrimaryQueueSpecificKey) != nil {
            closure()
        } else {
            self.sessionPrimaryQueue.sync(execute: closure)
        }
    }
}

private extension AVCaptureDevice.Position {
    func opposite() -> AVCaptureDevice.Position {
        switch self {
        case .front: return .back
        case .back: return .front
        case .unspecified: return .unspecified
        }
    }
}

private extension AVFileType {
    // swiftlint:disable cyclomatic_complexity file_length
    func stringValue() -> String {
        var string = ""
        switch self {
        case .mov: string += "mov"
        case .mp4: string += "mp4"
        case .m4v: string += "m4v"
        case .m4a: string += "m4a"
        case .mobile3GPP: string += "3gp"
        case .mobile3GPP2: string += "3g2"
        case .caf: string += "caf"
        case .wav: string += "wav"
        case .aiff: string += "aif"
        case .aifc: string += "aifc"
        case .amr: string += "amr"
        case .mp3: string += "mp3"
        case .au: string += "au"
        case .ac3: string += "ac3"
        case .eac3: string += "eac3"
        case .jpg: string += "jpg"
        case .dng: string += "dng"
        case .heic: string += "heic"
        case .avci: string += "avci"
        case .heif: string += "heif"
        case .tif: string += "tiff"
        default: fatalError("AVFileType: \(self.rawValue) not supported")
        }
        return string
    }

    var isImageFileTypeSupported: Bool {
        return self == .heic || self == .jpg || self == .tif
    }

    var isVideoFileTypeSupported: Bool {
        return self == .mov || self == .mp4 || self == .mobile3GPP || self == .mobile3GPP2
    }
}
