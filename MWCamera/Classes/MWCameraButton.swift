//
//  MWCameraButton.swift
//  MWCamera
//
//  Created by Woody Jean-Louis on 5/18/19.
//

import UIKit

open class MWCameraButton: UIView {
    var isEnabled: Bool {
        didSet {
            if isUserInteractionEnabled != isEnabled {
                isUserInteractionEnabled = isEnabled
            }
        }
    }

    override open var isUserInteractionEnabled: Bool {
        didSet {
            if isUserInteractionEnabled != isEnabled {
                isEnabled = isUserInteractionEnabled
            }
        }
    }

    public var longPressGestureRecognizer: UILongPressGestureRecognizer?

    public init() {
        self.isEnabled = true
        super.init(frame: .zero)
        self.isUserInteractionEnabled = true

    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
