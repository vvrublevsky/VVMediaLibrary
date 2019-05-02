//
//  ViewController.swift
//  VVMediaLibrary
//
//  Created by Volodymyr Vrublevskyi on 4/18/19.
//  Copyright © 2019 NerdzLab. All rights reserved.
//

import UIKit
import Photos
import Reusable

protocol GalleryDelegate: class {
    func didSelectPhotoFromGallery(_ photo: UIImage)
    func didSelectVideoFromGallery(_ video: PHAsset)
    func didDismissGallery()
}

class GalleryViewController: UIViewController {
    
    enum MediaType: Int {
        case any
        case photos
        case videos
    }
    
    private enum ContentType {
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
            contentCollectionView.register(cellType: GalleryAlbumCollectionViewCell.self)
            contentCollectionView.register(cellType: GalleryItemCollectionViewCell.self)
        }
    }
    
    @IBOutlet private var activityIndicatorView: UIActivityIndicatorView!
    
    // MARK: Public variables
    
    var mediaType: MediaType = .photos
    
    weak var delegate: GalleryDelegate?
    
    // MARK: Private variables
    
    private var contentType: ContentType = .albums {
        didSet {
            contentCollectionView.reloadData()
            
            arrowImageView.image = contentType == .albums ? UIImage(named: "up-icon") : UIImage(named: "dropdown-icon")
        }
    }
    
    private var albumsDataSource: [GalleryAlbum] = []
    
    private var selectedAlbum: GalleryAlbum?
    
    private var networkGroup: DispatchGroup = DispatchGroup()
    
    private lazy var downloadQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download queue"
        queue.maxConcurrentOperationCount = 50
        return queue
    }()
    
    // MARK: Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepareAlbums()
    }
    
    // MARK: IBActions
    
    @IBAction private func didPressCloseButton() {
        delegate?.didDismissGallery()
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
                } else {
                    self?.presentAlert("Oops", "Please provide photo library access.")
                }
            }
        }
    }
    
    private func fetchAlbums() {
        let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        
        albumsDataSource = []
        
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
                
                self.albumsDataSource.append(album)
            }
        }
        
        albumsDataSource.sort { $0.collection.localizedTitle ?? "" < $1.collection.localizedTitle ?? "" }
        
        fetchAlbumsThumbnails {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                self.stopRefreshAnimation()
                self.contentCollectionView.isHidden = false
                self.contentCollectionView.reloadData()
            })
        }
    }
    
    private func fetchAlbumsThumbnails(completion: @escaping (()->Void)) {
        for album in albumsDataSource {
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
}

// MARK: UICollectionView DataSource

extension GalleryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch contentType {
        case .albums:
            return albumsDataSource.count
        case .mediaItems:
            return selectedAlbum?.assets.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch contentType {
        case .albums:
            let album = albumsDataSource[indexPath.row]
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
        return thumbnailSizeForContent(contentType)
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
            if let album = albumsDataSource[safeIndex: indexPath.row] {
                displayAlbum(album)
            }
            
        case .mediaItems:
            
            switch mediaType {
            case .photos:
                
                // Get fullscreen image, i.e. with highest quality.
                if let asset = selectedAlbum?.assets[safeIndex: indexPath.row] {
                    startRefreshAnimation()
                    contentCollectionView.isHidden = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.thumbnailForAsset(asset, size: PHImageManagerMaximumSize) { [weak self] image in
                            if let photo = image {
                                self?.delegate?.didSelectPhotoFromGallery(photo)
                                self?.stopRefreshAnimation()
                                self?.contentCollectionView.isHidden = false
                            }
                        }
                    }
                }
            case .videos:
                if let asset = selectedAlbum?.assets[safeIndex: indexPath.row] {
                    delegate?.didSelectVideoFromGallery(asset)
                }
            default:
                break
            }
            
        }
    }
    
    private func thumbnailSizeForContent(_ contentType: ContentType) -> CGSize {
        switch contentType {
        case .albums:
            return CGSize(width: contentCollectionView.bounds.width - CollectionConstants.itemInset * 2,
                          height: CollectionConstants.albumsCollectionItemHeight)
            
        case .mediaItems:
            let cellWidth = (view.bounds.width - CollectionConstants.itemInset * 4)/3
            let cellHeight = cellWidth
            
            return CGSize(width: cellWidth,
                          height: cellHeight)
        }
    }
    
    private func displayAlbum(_ album: GalleryAlbum) {
        selectedAlbum = album
        albumTitleLabel.text = album.collection.localizedTitle
        
        startRefreshAnimation()
        contentCollectionView.isHidden = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.contentType = .mediaItems
            self.contentCollectionView.reloadData()
            self.stopRefreshAnimation()
            self.contentCollectionView.isHidden = false
        }
    }
}

// MARK: - Refresh animation

private extension GalleryViewController {
    func startRefreshAnimation() {
        activityIndicatorView.isHidden = false
        activityIndicatorView.startAnimating()
    }
    
    func stopRefreshAnimation() {
        activityIndicatorView.isHidden = true
        activityIndicatorView.stopAnimating()
    }
}

