//
//  SimilarViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/6.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit

class SimilarViewController: UIViewController {

    @IBOutlet weak var similarCollection: UICollectionView!
    var files: [URL] = []
    var filePath: URL = documentsPath
    var images: [UIImage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        similarCollection.dataSource = self
        similarCollection.delegate = self
//        if let files = try? FileManager.default.contentsOfDirectory(atPath: filePath.path) {
//            self.files = files.map { filePath.appendingPathComponent($0) }
//        }
//        print(files)
    }
}

extension SimilarViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "picturecell", for: indexPath) as! TemplateCell
        let image = images[indexPath.item]
        cell.imageview.image = image
        cell.label.text = ""
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 150, height: 200)
    }
}
