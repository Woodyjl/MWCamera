//
//  MWCameraDelegate.swift
//  MWCamera
//
//  Created by Woody Jean-Louis on 5/17/19.
//
import AVFoundation

// swiftlint:disable line_length
@objc public protocol MWCameraDelegate: class {
    /**
     MWBaseCameraViewControllerDelegate function called before MWBaseCameraViewController begins recording video.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter camera: Current camera orientation
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, willBeginRecordingVideoAt location: MWCameraLocation)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController begins recording video.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter camera: Current camera orientation
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didBeginRecordingVideoAt location: MWCameraLocation)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController updates recording duration.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter duration: The total duration of the current recording
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didUpdateRecordingDurationTo duration: Double)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController finishes recording video.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter camera: Current camera orientation
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didFinishRecordingVideoAt location: MWCameraLocation)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController is done processing video.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter url: URL location of video in temporary directory
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didFinishProcessingVideoAt url: URL)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController fails to record a video.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter error: An error object that describes the problem
     */
    @objc optional func mwCamera(_ mwCamera: MWCamera, didFailToRecordVideo error: Error)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController switches between front or rear camera.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter camera: Current camera selection
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didSwitchCamera location: MWCameraLocation)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController view is tapped and begins focusing at that point.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter point: Location in view where camera focused
     
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didFocusAtPoint point: CGPoint)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController view changes zoom level.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter zoom: Current zoom level
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didChangeZoomLevelTo zoomLevel: CGFloat)

    /**
     MWBaseCameraViewControllerDelegate function called when MWBaseCameraViewController view changes zoom level.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     - Parameter zoom: Current zoom level
     */

    @objc optional func mwCamera(_ mwCamera: MWCamera, didCancelRecordingAt url: URL)
    
    /**
     MWBaseCameraViewControllerDelegate function called right before MWBaseCameraViewController
     checks for an asset writer and inputs or creates one.
     
     - Parameter mwCamera: Current MWBaseCameraViewController session
     */
    
    @objc optional func mwCamera(shouldCreateAssetWriter mwCamera: MWCamera)
}
