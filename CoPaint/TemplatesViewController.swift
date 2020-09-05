//
//  TemplatesViewController.swift
//  CoPaint
//
//  Created by 张睿杰 on 2020/9/5.
//  Copyright © 2020 张睿杰. All rights reserved.
//

import UIKit

let templates = ["flower", "frog", "plane", "snowman", "tree", "umbrella"]
let documentsPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("pictures")

class TemplateCell: UICollectionViewCell {
    @IBOutlet weak var imageview: UIImageView!
    @IBOutlet weak var label: UILabel!
}

class TemplatesViewController: UIViewController {

    @IBOutlet weak var templateCollection: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        templateCollection.delegate = self
        templateCollection.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let alert = UIAlertController(title: "hahah", message: "Hellow World", preferredStyle: .alert)
        alert.addTextField { (textfield) in
            textfield.placeholder = "Type your code here"
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func cancel(_ unwindSegue: UIStoryboardSegue) {}
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "paintsegue" {
            let controller = segue.destination as! PaintViewController
            let recognizer = sender as! UITapGestureRecognizer
            let cell = recognizer.view as! TemplateCell
            let indexPath = templateCollection.indexPath(for: cell)
            print(indexPath!.item, "indexpath")
            dump(indexPath)
            controller.templateImage = cell.imageview.image
            controller.templateIndex = indexPath!.item
        }
    }
    
    @IBAction func cellTapped(recognizer: UITapGestureRecognizer) {
        self.performSegue(withIdentifier: "paintsegue", sender: recognizer)
    }
}

extension TemplatesViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return templates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "templatecell", for: indexPath) as! TemplateCell
        let name = templates[indexPath.item]
        cell.label.text = name
        let imageURL = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "templates")!
        cell.imageview.image = UIImage(contentsOfFile: imageURL.path)
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(cellTapped(recognizer:)))
        cell.addGestureRecognizer(gestureRecognizer)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 150, height: 200)
    }
}
