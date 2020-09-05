//
//  GalleryViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit
import QuickLook
import Alamofire
import SwiftyJSON

class GalleryViewController: UIViewController {

    @IBOutlet weak var picturesCollection: UICollectionView!
    var files: [URL] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        picturesCollection.delegate = self
        picturesCollection.dataSource = self
        if let files = try? FileManager.default.contentsOfDirectory(atPath: documentsPath.path) {
            self.files = files.map { documentsPath.appendingPathComponent($0) }
        }
        print(files)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        picturesCollection.reloadData()
        AF.request("https://go.hqy.moe/paintings/list").response { response in
            let json = JSON(response.data)
            let firstPic = json["data"][0]
            //print(firstPic["image"].string)
            var base64 = firstPic["image"].string ?? ""
            base64 = base64.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            print(base64)
            if let decodedData = Data(base64Encoded: base64) {
                let image = UIImage(data: decodedData)
                let pngdata = image?.pngData()
                try! pngdata?.write(to: documentsPath.appendingPathComponent("testserver.png"))
                print(documentsPath, "good")
            }
        }
    }

}

extension GalleryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return files.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "picturecell", for: indexPath) as! TemplateCell
        let image = UIImage(contentsOfFile: files[indexPath.row].path)
        cell.imageview.image = image
        cell.label.text = ""
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 150, height: 200)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.currentPreviewItemIndex = indexPath.item
        self.present(previewController, animated: true, completion: nil)
    }
}

extension GalleryViewController: QLPreviewControllerDataSource {
    var previewItems: [QLPreviewItem] {
        return self.files as [QLPreviewItem]
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return previewItems.count
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewItems[index]
    }
    
    
}
