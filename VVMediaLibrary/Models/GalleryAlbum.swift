//
//  GalleryAlbum.swift
//  VVMediaLibrary
//
//  Created by Volodymyr Vrublevskyi on 4/26/19.
//  Copyright © 2019 NerdzLab. All rights reserved.
//

import UIKit
import Photos

class GalleryAlbum {
    var collection: PHAssetCollection
    var thumbnail: UIImage?
    var assets: [PHAsset] = []
    var assetsThumbnails: [UIImage] = []
    
    init(collection: PHAssetCollection) {
        self.collection = collection
    }
}
