//
//  TemplatesViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit

class TemplatesViewController: UIViewController {

    @IBOutlet weak var templateCollection: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        templateCollection.delegate = self
        templateCollection.dataSource = self
    }

}

extension TemplatesViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "templatecell", for: indexPath)
        cell.backgroundColor = .blue
        return cell
    }
}
