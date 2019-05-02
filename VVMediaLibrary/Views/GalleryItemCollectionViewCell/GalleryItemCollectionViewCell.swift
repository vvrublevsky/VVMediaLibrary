//
//  GalleryItemCollectionViewCell.swift
//  InTheKnow
//
//  Created by Volodymyr Vrublevskyi on 1/8/19.
//  Copyright © 2019 NerdzLab. All rights reserved.
//

import UIKit
import Reusable

class GalleryItemCollectionViewCell: UICollectionViewCell, NibReusable {
    
    // MARK: IBOutlets
    
    @IBOutlet private var durationOverlayView: UIView!
    
    @IBOutlet private var durationLabel: UILabel!
    
    @IBOutlet private var photoImageView: UIImageView!
    
    // MARK: Variables
    
    var preview: UIImage? {
        didSet {
            photoImageView.image = preview
        }
    }
    
    var hasDuration: Bool = false {
        didSet {
            durationOverlayView.isHidden = !hasDuration
        }
    }
    
    var duration: Int = 0 {
        didSet {
            durationLabel.text = duration.toMinutesString()
        }
    }
}
