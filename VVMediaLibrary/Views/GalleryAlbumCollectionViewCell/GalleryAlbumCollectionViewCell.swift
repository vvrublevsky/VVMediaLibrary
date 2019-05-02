//
//  GalleryAlbumCollectionViewCell.swift
//  InTheKnow
//
//  Created by Volodymyr Vrublevskyi on 1/8/19.
//  Copyright © 2019 NerdzLab. All rights reserved.
//

import UIKit
import Reusable

class GalleryAlbumCollectionViewCell: UICollectionViewCell, NibReusable {
    
    // MARK: IBOutlets
    
    @IBOutlet private var albumImageView: UIImageView!
    
    @IBOutlet private var titleLabel: UILabel!
    
    @IBOutlet private var photosCountLabel: UILabel!
    
    // MARK: Variables
    
    var image: UIImage? {
        didSet {
            albumImageView.image = image
        }
    }
    
    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    
    var photosCount: Int = 0 {
        didSet {
            photosCountLabel.text = "\(photosCount)"
        }
    }
}
