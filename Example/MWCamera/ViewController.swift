//
//  ViewController.swift
//  MWCamera
//
//  Created by woodyjl on 05/14/2019.
//  Copyright (c) 2019 woodyjl. All rights reserved.
//

import UIKit
import MWCamera
import AVFoundation

class ViewController: CameraViewController {
    private var audioPermission: AVAudioSession.RecordPermission = .denied
    private var videoPermission: AVAuthorizationStatus = .denied

    private var permissionView: UIView!
    private var cameraPermissionButton: UIButton!
    private var audioPermissionButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        observePermissions()
        handlePermissions()
    }

    override func setPreviousBackgroundAudioPreference() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            let options: AVAudioSession.CategoryOptions = [
                .mixWithOthers
            ]
            try audioSession.setActive(false)
            try audioSession.setCategory(AVAudioSession.Category.playback, options: options)
            try audioSession.setActive(true)
        } catch {
            print(error)
            print("Failed to set background audio preference \(error.localizedDescription)")
        }
    }

    override func mwCamera(_ mwCamera: MWCamera, didSwitchCamera location: MWCameraLocation) {
        if let device = self.captureDevice {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }

                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }

                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                if device.isLowLightBoostSupported {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                }

                device.unlockForConfiguration()
            } catch {
                print("[mwCamera]: Error locking configuration")
            }
        }
    }
}

extension ViewController {
    func addPermissionsView() {
        guard permissionView == nil else { return }

        permissionView = UIView()
        permissionView.frame = view.bounds

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        let title = "Welcome To MWCamera" + "\n\n"
        let subtitle = "Can I please have your permission to your cam and mic 😅.\n"

        var attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.title1)
        ]
        let attributedTitle = NSAttributedString(string: title, attributes: attributes)

        attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.lightGray,
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        ]
        let attributedSubtitle = NSAttributedString(string: subtitle, attributes: attributes)

        let attritbutedText = NSMutableAttributedString()
        attritbutedText.append(attributedTitle)
        attritbutedText.append(attributedSubtitle)

        titleLabel.attributedText = attritbutedText
        titleLabel.textAlignment = .center

        cameraPermissionButton = UIButton()
        audioPermissionButton = UIButton()
        let color = UIColor.init(red: 217.00 / 255.0, green: 156.0 / 255.0, blue: 60.0 / 255.0, alpha: 1.0)
        cameraPermissionButton.setTitleColor(color, for: .normal)
        cameraPermissionButton.setTitle("Allow camera access", for: .normal)
        cameraPermissionButton.setTitleColor(color.withAlphaComponent(0.5), for: .disabled)
        cameraPermissionButton.setTitle("Camera access granted", for: .disabled)
        cameraPermissionButton.addTarget(self, action: #selector(askForCameraPermission(_:)), for: .touchUpInside)
        cameraPermissionButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        cameraPermissionButton.isEnabled = videoPermission != .authorized

        audioPermissionButton.setTitleColor(color, for: .normal)
        audioPermissionButton.setTitle("Allow microphone access", for: .normal)
        audioPermissionButton.setTitleColor(color.withAlphaComponent(0.5), for: .disabled)
        audioPermissionButton.setTitle("Microphone access granted", for: .disabled)
        audioPermissionButton.addTarget(self, action: #selector(askForAudioPermission(_:)), for: .touchUpInside)
        audioPermissionButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        audioPermissionButton.isEnabled = audioPermission != .granted

        let stackView = UIStackView(arrangedSubviews: [titleLabel, cameraPermissionButton, audioPermissionButton])
        stackView.alignment = .center
        stackView.distribution = .fillProportionally
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        permissionView.addSubview(stackView)

        stackView.centerYAnchor.constraint(equalTo: permissionView.centerYAnchor).isActive = true
        stackView.centerXAnchor.constraint(equalTo: permissionView.centerXAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: permissionView.widthAnchor, multiplier: 0.75).isActive = true
        stackView.heightAnchor.constraint(equalTo: permissionView.heightAnchor, multiplier: 0.5).isActive = true

        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = permissionView.frame
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        permissionView.insertSubview(blurEffectView, belowSubview: stackView)

        view.addSubview(permissionView)
    }

    @objc fileprivate func askForCameraPermission(_ sender: UIButton) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [weak self] (granted) in
            OperationQueue.main.addOperation {
                if granted {
                    DispatchQueue.main.async {
                        self?.cameraPermissionButton.isEnabled = self?.videoPermission != .authorized
                    }
                    self?.observePermissions()
                    self?.handlePermissions()
                    return
                }
                self?.presentGoToSettingsAlert()
            }
        })
    }

    @objc fileprivate func askForAudioPermission(_ sender: UIButton) {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] (granted) in
            OperationQueue.main.addOperation {
                if granted {
                    DispatchQueue.main.async {
                        self?.audioPermissionButton.isEnabled = self?.audioPermission != .granted
                    }
                    self?.observePermissions()
                    self?.handlePermissions()
                    return
                }
                self?.presentGoToSettingsAlert()
            }
        }
    }

    fileprivate func presentGoToSettingsAlert() {
        let message = "MWCamera requires access to your camera and microphone, please change privacy settings."
        let alertController = UIAlertController(title: "😔", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            UIApplication.shared.open(
                URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }))
        present(alertController, animated: true, completion: nil)
    }
}

extension ViewController {
    func observePermissions() {
        videoPermission = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        audioPermission = AVAudioSession.sharedInstance().recordPermission
    }

    func handlePermissions() {
        let isVideoEnabled = videoPermission == .authorized
        let isAudioEnabled = audioPermission == .granted

        if isVideoEnabled && isAudioEnabled {
            self.permissionView?.removeFromSuperview()

            self.reconfigureSession()
            // Best time to configure video Input and outputs

            if let device = self.captureDevice {
                do {
                    try device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }

                    if device.isSmoothAutoFocusSupported {
                        device.isSmoothAutoFocusEnabled = true
                    }

                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }

                    if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        device.whiteBalanceMode = .continuousAutoWhiteBalance
                    }

                    if device.isLowLightBoostSupported {
                        device.automaticallyEnablesLowLightBoostWhenAvailable = true
                    }

                    device.unlockForConfiguration()
                } catch {
                    print("[mwCamera]: Error locking configuration")
                }
            }

            if self.isSessionRunning != true {
                self.beginSession()
            }
        } else {
            self.addPermissionsView()
        }
    }
}
