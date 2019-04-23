//
//  ViewController.swift
//  VVMediaLibrary
//
//  Created by Volodymyr Vrublevskyi on 4/18/19.
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

class GalleryViewController: UIViewController {
    
    enum MediaType: Int {
        case all
        case photos
        case videos
    }
    
    enum ContentType {
        case albums
        case mediaItems
    }
    
    // MARK: Constants
    
    fileprivate struct CollectionConstants {
        static let albumsCollectionItemHeight: CGFloat = 40.0
        static let itemInset: CGFloat = 14.0
    }
    
    // MARK: IBOutlets
    
    @IBOutlet private var albumTitleLabel: UILabel!
    
    @IBOutlet private var arrowImageView: UIImageView!
    
    @IBOutlet private var contentCollectionView: UICollectionView! {
        didSet {
//            contentCollectionView.register(cellType: GalleryAlbumCollectionViewCell.self)
//            contentCollectionView.register(cellType: GalleryItemCollectionViewCell.self)
        }
    }
    
    @IBOutlet private var refreshAnimationImageView: UIImageView!
    
    // MARK: Public variables
    
    var mediaType: MediaType = .photos
    
    var onPhotoDidSelectCompletion: ((_ photo: UIImage) -> Void)?
    var onVideoDidSelectCompletion: ((_ video: PHAsset) -> Void)?
    var onDismissCompletion: (() -> Void)?
    
    // MARK: Private variables
    
    fileprivate var contentType: ContentType = .albums {
        didSet {
            contentCollectionView.reloadData()
            arrowImageView.image = contentType == .albums ? UIImage(named: "up-icon") : UIImage(named: "dropdown-icon")
        }
    }
    
    fileprivate var albums: [GalleryAlbum] = []
    
    fileprivate var selectedAlbum: GalleryAlbum?
    
    fileprivate var networkGroup: DispatchGroup = DispatchGroup()
    
    fileprivate lazy var downloadQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download queue"
        queue.maxConcurrentOperationCount = 50
        return queue
    }()
    
    // MARK: Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupRefreshAnimation()
        
        prepareAlbums()
    }
    
    // MARK: IBActions
    
    @IBAction private func didPressCloseButton() {
        onDismissCompletion?()
    }
    
    @IBAction private func didPressSelectAlbumButton() {
        contentType = .albums
    }
}

// MARK: - Albums Setup

private extension GalleryViewController {
    
    func prepareAlbums() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self?.fetchAlbums()
                }
            }
        }
    }
    
    func displayAlbum(_ album: GalleryAlbum) {
        selectedAlbum = album
        albumTitleLabel.text = album.collection.localizedTitle
        
        setupRefreshAnimation()
        contentCollectionView.isHidden = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.contentType = .mediaItems
            self.contentCollectionView.reloadData()
            self.contentCollectionView.isHidden = false
            self.stopRefreshAnimation()
        }
    }
    
    private func fetchAlbums() {
        
        let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        
        albums = []
        
        let assetsFetchOptions = PHFetchOptions()
        assetsFetchOptions.predicate = NSPredicate(format: "mediaType = %i", mediaType.rawValue)
        assetsFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        collections.enumerateObjects { (assetCollection, index, stop) in
            let assets = PHAsset.fetchAssets(in: assetCollection, options: assetsFetchOptions)
            
            var content: [PHAsset] = []
            assets.enumerateObjects({ (asset, _, _) in
                content.append(asset)
            })
            
            if content.count > 0 {
                let album = GalleryAlbum(collection: assetCollection)
                album.assets = content
                
                self.albums.append(album)
            }
        }
        
        albums.sort { $0.collection.localizedTitle ?? "" < $1.collection.localizedTitle ?? "" }
        
        fetchAlbumsThumbnails {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                self.contentCollectionView.isHidden = false
                self.contentCollectionView.reloadData()
                self.stopRefreshAnimation()
            })
        }
    }
    
    private func fetchAlbumsThumbnails(completion: @escaping (()->Void)) {
        
        for album in albums {
            networkGroup.enter()
            
            let size = CGSize(width: CollectionConstants.albumsCollectionItemHeight,
                              height: CollectionConstants.albumsCollectionItemHeight)
            
            thumbnailForAsset(album.assets.first, size: size) { [weak self] image in
                album.thumbnail = image
                self?.networkGroup.leave()
            }
        }
        
        networkGroup.notify(queue: .main, execute: completion)
    }
    
    private func thumbnailForAsset(_ asset: PHAsset?, size: CGSize, completion: @escaping (_ image: UIImage?) -> Void) {
        guard let asset = asset else {
            completion(nil)
            return
        }
        
        let option = PHImageRequestOptions()
        option.resizeMode = .fast
        option.deliveryMode = .opportunistic
        option.isSynchronous = true
        option.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: option, resultHandler: { result, _ in
            completion(result)
        })
    }
    
    private func thumbnailSizeForContent(_ contentType: ContentType) -> CGSize {
        switch contentType {
        case .albums:
            return CGSize(width: CollectionConstants.albumsCollectionItemHeight,
                          height: CollectionConstants.albumsCollectionItemHeight)
            
        case .mediaItems:
            let cellWidth = (view.bounds.width - CollectionConstants.itemInset * 4)/3
            let cellHeight = cellWidth
            
            return CGSize(width: cellWidth,
                          height: cellHeight)
        }
    }
}

// MARK: UICollectionView DataSource

extension GalleryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch contentType {
        case .albums:
            return albums.count
        case .mediaItems:
            return selectedAlbum?.assets.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch contentType {
        case .albums:
            let album = albums[indexPath.row]
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: GalleryAlbumCollectionViewCell.self)
            cell.title = album.collection.localizedTitle
            cell.photosCount = album.assets.count
            cell.image = album.thumbnail
            
            return cell
            
        case .mediaItems:
            let cell = collectionView.dequeueReusableCell(for: indexPath, cellType: GalleryItemCollectionViewCell.self)
            
            guard let asset = selectedAlbum?.assets[safeIndex: indexPath.row] else { return cell }
            
            if asset.mediaType.rawValue == MediaType.videos.rawValue {
                cell.hasDuration = true
                cell.duration = Int(asset.duration)
            } else {
                cell.hasDuration = false
            }
            
            setPreviewForAsset(asset, in: cell)
            
            return cell
        }
    }
    
    private func setPreviewForAsset(_ asset: PHAsset, in cell: GalleryItemCollectionViewCell) {
        let cellWidth = (contentCollectionView.bounds.width - CollectionConstants.itemInset * 4)/3
        let size = CGSize(width: cellWidth * 3, height: cellWidth * 3)
        
        downloadQueue.addOperation {
            let option = PHImageRequestOptions()
            option.resizeMode = .fast
            option.deliveryMode = .opportunistic
            option.isSynchronous = true
            option.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: option, resultHandler: { result, _ in
                OperationQueue.main.addOperation {
                    cell.preview = result
                }
            })
        }
    }
}

// MARK: - UICollectionView DelegateFlowLayout

extension GalleryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch contentType {
        case .albums:
            return CGSize(width: collectionView.bounds.width - CollectionConstants.itemInset * 2,
                          height: CollectionConstants.albumsCollectionItemHeight)
            
        case .mediaItems:
            return thumbnailSizeForContent(.mediaItems)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CollectionConstants.itemInset
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: CollectionConstants.itemInset,
                            left: CollectionConstants.itemInset,
                            bottom: 30.0,
                            right: CollectionConstants.itemInset)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch contentType {
        case .albums:
            if let album = albums[safeIndex: indexPath.row] {
                displayAlbum(album)
            }
            
        case .mediaItems:
            
            switch mediaType {
            case .photos:
                // Show fullscreen image
                if let asset = selectedAlbum?.assets[safeIndex: indexPath.row] {
                    setupRefreshAnimation()
                    contentCollectionView.isHidden = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.thumbnailForAsset(asset, size: PHImageManagerMaximumSize) { [weak self] image in
                            if let photo = image {
                                self?.onPhotoDidSelectCompletion?(photo)
                                
                                self?.contentCollectionView.isHidden = false
                                self?.stopRefreshAnimation()
                            }
                        }
                    }
                }
                
            case .videos:
                if let asset = selectedAlbum?.assets[safeIndex: indexPath.row] {
                    onVideoDidSelectCompletion?(asset)
                }
                
            default:
                break
            }
            
        }
    }
}

// MARK: - Refresh animation

private extension GalleryViewController {
    func setupRefreshAnimation() {
//        let gif = UIImage(gifName: "Refreshing.gif")
//        refreshAnimationImageView.setGifImage(gif, loopCount: -1)
//        refreshAnimationImageView.startAnimatingGif()
    }
    
    func stopRefreshAnimation() {
//        refreshAnimationImageView.stopAnimatingGif()
    }
}
